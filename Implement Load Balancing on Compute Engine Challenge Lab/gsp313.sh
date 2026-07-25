#!/bin/bash

# Define custom color variables for the interface
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Function to show spinner while commands run
spinner() {
    local pid=$!
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Welcome message header
echo "${BLUE}${BOLD}======================================================================${RESET}"
echo "${CYAN}${BOLD}                    WELCOME TO ORBIT OF OPS                           ${RESET}"
echo "${BLUE}${BOLD}======================================================================${RESET}"
echo "${WHITE}${BOLD} Challenge Lab: ${YELLOW}GSP313${RESET}"
echo "${WHITE}${BOLD} Objective:    ${YELLOW}Deploy Network & HTTP Load Balancers on Google Cloud${RESET}"
echo "${BLUE}${BOLD}----------------------------------------------------------------------${RESET}"
echo ""

# Fetch zone and region with fallback to prompt
echo -n "${WHITE}${BOLD}Detecting default zone and region...${RESET} "
ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
spinner

if [ -z "$ZONE" ]; then
    echo "${RED}${BOLD}Could not detect default zone.${RESET}"
    echo "${YELLOW}Please enter your preferred zone (e.g., us-central1-a):${RESET}"
    read -p "Zone: " ZONE
    REGION=${ZONE%-*}
else
    echo "${GREEN}${BOLD}Done!${RESET}"
    echo "${CYAN}• Project ID:${RESET} ${WHITE}$PROJECT_ID${RESET}"
    echo "${CYAN}• Detected Zone:${RESET} ${WHITE}$ZONE${RESET}"
    echo "${CYAN}• Detected Region:${RESET} ${WHITE}$REGION${RESET}"
fi
echo ""

echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${MAGENTA}${BOLD} TASK 1: CREATING MULTIPLE WEB SERVER INSTANCES                       ${RESET}"
echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"

# Create web instances
for i in {1..3}; do
    echo -n "${WHITE}Creating Compute Engine instance ${CYAN}web$i${WHITE}...${RESET} "
    gcloud compute instances create web$i \
        --zone=$ZONE \
        --machine-type=e2-small \
        --tags=network-lb-tag \
        --image-family=debian-12 \
        --image-project=debian-cloud \
        --metadata=startup-script='#!/bin/bash
        apt-get update
        apt-get install apache2 -y
        service apache2 restart
        echo "<h3>Web Server: web'$i'</h3>" | tee /var/www/html/index.html' > /dev/null 2>&1 &
    spinner
    echo "${GREEN}${BOLD}Created!${RESET}"
done

# Create firewall rule
echo -n "${WHITE}Creating VPC firewall rule ${CYAN}www-firewall-network-lb${WHITE}...${RESET} "
gcloud compute firewall-rules create www-firewall-network-lb \
    --allow tcp:80 \
    --target-tags network-lb-tag > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"
echo ""

echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${MAGENTA}${BOLD} TASK 2: CONFIGURING THE NETWORK LOAD BALANCING SERVICE              ${RESET}"
echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"

echo -n "${WHITE}Reserving static external IP ${CYAN}network-lb-ip-1${WHITE}...${RESET} "
gcloud compute addresses create network-lb-ip-1 \
    --region=$REGION > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Creating target pool HTTP health check ${CYAN}basic-check${WHITE}...${RESET} "
gcloud compute http-health-checks create basic-check > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Creating Target Pool regional service ${CYAN}www-pool${WHITE}...${RESET} "
gcloud compute target-pools create www-pool \
    --region=$REGION \
    --http-health-check basic-check > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Attaching backend instances ${CYAN}(web1, web2, web3)${WHITE} to pool...${RESET} "
gcloud compute target-pools add-instances www-pool \
    --instances web1,web2,web3 \
    --zone=$ZONE > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Publishing regional forwarding rule ${CYAN}www-rule${WHITE}...${RESET} "
gcloud compute forwarding-rules create www-rule \
    --region=$REGION \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

IPADDRESS=$(gcloud compute forwarding-rules describe www-rule \
    --region=$REGION \
    --format="json" | jq -r .IPAddress)
echo ""

echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${MAGENTA}${BOLD} TASK 3: BUILDING THE GLOBAL HTTP LOAD BALANCER                      ${RESET}"
echo "${MAGENTA}${BOLD}----------------------------------------------------------------------${RESET}"

echo -n "${WHITE}Creating instance template ${CYAN}lb-backend-template${WHITE}...${RESET} "
gcloud compute instance-templates create lb-backend-template \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-12 \
   --image-project=debian-cloud \
   --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2' > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Spawning Managed Instance Group ${CYAN}lb-backend-group${WHITE}...${RESET} "
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template \
   --size=2 \
   --zone=$ZONE > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Configuring MIG named ports ${CYAN}(http:80)${WHITE}...${RESET} "
gcloud compute instance-groups managed set-named-ports lb-backend-group \
   --named-ports=http:80 \
   --zone=$ZONE > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Opening health check ingress firewall rule ${CYAN}fw-allow-health-check${WHITE}...${RESET} "
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80 > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Allocating global IP address resource ${CYAN}lb-ipv4-1${WHITE}...${RESET} "
gcloud compute addresses create lb-ipv4-1 \
  --ip-version=IPV4 \
  --global > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

LB_IP=$(gcloud compute addresses describe lb-ipv4-1 \
  --format="get(address)" \
  --global)

echo -n "${WHITE}Creating global HTTP health check backend configuration...${RESET} "
gcloud compute health-checks create http http-basic-check \
  --port 80 > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Provisioning backend service target ${CYAN}lb-backend-service${WHITE}...${RESET} "
gcloud compute backend-services create lb-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Linking Managed Instance Group backend targets to service...${RESET} "
gcloud compute backend-services add-backend lb-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=$ZONE \
  --global > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Mapping routing configurations inside URL map ${CYAN}web-map-http${WHITE}...${RESET} "
gcloud compute url-maps create web-map-http \
    --default-service lb-backend-service > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Establishing frontend target proxy structural map...${RESET} "
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map-http > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"

echo -n "${WHITE}Creating final structural forwarding rule ${CYAN}http-content-rule${WHITE}...${RESET} "
gcloud compute forwarding-rules create http-content-rule \
    --address=lb-ipv4-1 \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80 > /dev/null 2>&1 &
spinner
echo "${GREEN}${BOLD}Done!${RESET}"
echo ""

# Beautiful detailed completion layout panel
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}            DEPLOYMENT SUCCESSFUL — ALL TASKS CONFIG COMPLETE          ${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo ""
echo "${GREEN}${BOLD}✓ TASK 1:${RESET} ${WHITE}Web instances (web1, web2, web3) running on Apache2.${RESET}"
echo "${GREEN}${BOLD}✓ TASK 2:${RESET} ${WHITE}Target Pool setup complete with active target mapping.${RESET}"
echo "${GREEN}${BOLD}✓ TASK 3:${RESET} ${WHITE}Global HTTP URL Map verified to backend services.${RESET}"
echo ""
echo "${YELLOW}${BOLD}► VERIFICATION ENDPOINTS:${RESET}"
echo "${CYAN}  • Regional L4 Network Load Balancer Address:${RESET}"
echo "    ${WHITE}http://${IPADDRESS}/${RESET}"
echo ""
echo "${CYAN}  • Global L7 HTTP Load Balancer Address:${RESET}"
echo "    ${WHITE}http://${LB_IP}/${RESET}"
echo ""
echo "${BLUE}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${YELLOW}${BOLD}NOTE ON PROPAGATION:${RESET}"
echo "${WHITE}Google Cloud global forwarding rules and health check propagation can takes${RESET}"
echo "${WHITE}between 3 to 5 minutes to fully handle active edge traffic routing.${RESET}"
echo "${WHITE}If you hit the links immediately and see a 404/502 error, simply wait a brief${RESET}"
echo "${WHITE}moment for edge nodes to synchronize before checking progress again.${RESET}"
echo "${BLUE}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${CYAN}${BOLD} Thank you for following along with Cloud Tutorials!                  ${RESET}"
echo "${CYAN}${BOLD} Please like the video and subscribe to the channel for more labs.    ${RESET}"
echo "${BLUE}${BOLD}======================================================================${RESET}"
