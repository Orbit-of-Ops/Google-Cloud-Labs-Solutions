clear

#!/bin/bash
# Define color variables

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

#----------------------------------------------------START--------------------------------------------------#

echo "${BLUE}${BOLD}======================================================================${RESET}"
echo "${CYAN}${BOLD}                     🚀  ORBIT OF OPS  🚀                            ${RESET}"
echo "${BLUE}${BOLD}======================================================================${RESET}"
echo "${WHITE}${BOLD} Challenge Lab: ${YELLOW}GSP155${RESET}"
echo "${WHITE}${BOLD} Architecture:  ${YELLOW}Layer 7 HTTP Application Load Balancer Implementation${RESET}"
echo "${BLUE}${BOLD}----------------------------------------------------------------------${RESET}"
echo ""

# Step 1: Set Zone and Region
echo "${CYAN}${BOLD}[1/7] ORBIT OF OPS 🚀 | Discovering Infrastructure Topologies...${RESET}"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
echo "${GREEN}${BOLD}✔ Targets Linked:${RESET} Zone: ${WHITE}$ZONE${RESET} | Region: ${WHITE}$REGION${RESET}"
echo ""

# Step 2: Create Compute Instances
echo "${MAGENTA}${BOLD}[2/7] ORBIT OF OPS 🚀 | Launching Layer 7 Web Nodes (www1, www2, www3)...${RESET}"
gcloud compute instances create www1 \
  --zone=$ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www1</h3>" | tee /var/www/html/index.html'

gcloud compute instances create www2 \
  --zone=$ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www2</h3>" | tee /var/www/html/index.html'

gcloud compute instances create www3 \
  --zone=$ZONE  \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www3</h3>" | tee /var/www/html/index.html'

# Step 3: Configure Firewall Rules
echo ""
echo "${YELLOW}${BOLD}[3/7] ORBIT OF OPS 🚀 | Establishing Ingress Perimeter Security Rules...${RESET}"
gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80

gcloud compute instances list
echo ""

# Step 4: Create Address and Load Balancer
echo "${BLUE}${BOLD}[4/7] ORBIT OF OPS 🚀 | Mapping L4 Regional Address Infrastructure...${RESET}"
gcloud compute addresses create network-lb-ip-1 \
  --region $REGION

gcloud compute http-health-checks create basic-check

gcloud compute target-pools create www-pool \
  --region $REGION --http-health-check basic-check

gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3

gcloud compute forwarding-rules create www-rule \
    --region  $REGION \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool

IPADDRESS=$(gcloud compute forwarding-rules describe www-rule --region $REGION --format="json" | jq -r .IPAddress)
echo ""

# Step 5: Instance Template and Managed Group
echo "${GREEN}${BOLD}[5/7] ORBIT OF OPS 🚀 | Structuring Managed Instance Group Scaling Policies...${RESET}"
gcloud compute instance-templates create lb-backend-template \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-11 \
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
     systemctl restart apache2'

gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template --size=2 --zone=$ZONE

# Adding required named ports mapping for L7 Traffic Routing
gcloud compute instance-groups managed set-named-ports lb-backend-group \
   --named-ports=http:80 --zone=$ZONE
echo ""

# Step 6: Configure Health Checks and URL Maps
echo "${RED}${BOLD}[6/7] ORBIT OF OPS 🚀 | Building Proxy Contexts & URL Maps...${RESET}"
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80

gcloud compute addresses create lb-ipv4-1 \
  --ip-version=IPV4 \
  --global

LB_IP=$(gcloud compute addresses describe lb-ipv4-1 --format="get(address)" --global)

gcloud compute health-checks create http http-basic-check \
  --port 80

gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global

gcloud compute backend-services add-backend web-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=$ZONE \
  --global

gcloud compute url-maps create web-map-http \
    --default-service web-backend-service

gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map-http

gcloud compute forwarding-rules create http-content-rule \
   --address=lb-ipv4-1\
   --global \
   --target-http-proxy=http-lb-proxy \
   --ports=80
echo ""

# Step 7: Automated Task 4 Validation Loop
echo "${YELLOW}${BOLD}[7/7] ORBIT OF OPS 🚀 | Monitoring Health Probe Synchronization Loop...${RESET}"
echo "${CYAN}Polling target backend service health statuses...${RESET}"

while true; do
  HEALTH_STATUS=$(gcloud compute backend-services get-health web-backend-service --global --format="value(status.healthStatus[0].healthState)" 2>/dev/null)
  
  if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then
     echo ""
     echo "${GREEN}${BOLD}✔ Verification Passed! Backend nodes have reached optimal HEALTHY operational thresholds.${RESET}"
     break
  else
     printf "${YELLOW}.${RESET}"
     sleep 10
  fi
done

echo ""

# Beautiful detailed completion layout panel with ORBIT OF OPS branding
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}        🚀 ORBIT OF OPS | ARCHITECTURE DEPLOYMENT SUCCESSFUL 🚀       ${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo ""
echo "${GREEN}${BOLD}✓ CORE PLATFORM:${RESET}   ${WHITE}L7 Forwarding Engine & Edge proxies successfully scaled.${RESET}"
echo "${GREEN}${BOLD}✓ PROBE ENGINE:${RESET}   ${WHITE}Automated health checker loop reported full infrastructure sync.${RESET}"
echo "${GREEN}${BOLD}✓ TASK 4 METRIC:${RESET}  ${WHITE}Active verification complete. Grade validation parameters metrics met.${RESET}"
echo ""
echo "${YELLOW}${BOLD}► ORBIT OF OPS TARGET ROUTING ENDPOINTS:${RESET}"
echo "${CYAN}  • Layer 4 Network Load Balancer Virtual IP:${RESET}"
echo "    ${WHITE}http://${IPADDRESS}/${RESET}"
echo ""
echo "${CYAN}  • Layer 7 Global Application Load Balancer IP:${RESET}"
echo "    ${WHITE}http://${LB_IP}/${RESET}"
echo ""
echo "${BLUE}${BOLD}----------------------------------------------------------------------${RESET}"
echo "${WHITE}Execution process finalized cleanly. You may now immediately prompt${RESET}"
echo "${WHITE}'Check My Progress' for Task 4 inside your Qwiklabs dashboard portal.${RESET}"
echo ""
echo "${CYAN}${BOLD} Thank you for choosing Orbit Of Ops!                                 ${RESET}"
echo "${CYAN}${BOLD} Don't forget to like this video and subscribe to stay updated!        ${RESET}"
echo "${BLUE}${BOLD}======================================================================${RESET}"

echo -e "\n"

cd

remove_files() {
    for file in *; do
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            if [[ -f "$file" ]]; then
                rm "$file"
            fi
        fi
    done
}

remove_files
