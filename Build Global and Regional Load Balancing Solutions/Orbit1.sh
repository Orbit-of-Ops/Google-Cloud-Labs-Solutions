#!/bin/bash
# Define color variables
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
CYAN_TEXT=$'\033[0;96m'
ORANGE_TEXT=$'\033[38;5;208m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
RESET_FORMAT=$'\033[0m'

clear
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}              🚀 WELCOME TO THE ORBIT OF OPS GUIDE 🚀             ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}             SCRIPT 1: REGIONAL INTERNAL PROXY NLB                ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter REGION_B (e.g., us-east4): ${RESET_FORMAT}" RAW_REGION_B
export REGION_B=$(echo "$RAW_REGION_B" | tr -d '\r ')
PROJECT_ID=$(gcloud config get-value project)

echo -e "\n${ORANGE_TEXT}[1/7] Creating Regional MIG for Internal Proxy...${RESET_FORMAT}"
gcloud compute instance-groups managed create mig-proxy-internal --region=$REGION_B --template=projects/$PROJECT_ID/regions/$REGION_B/instanceTemplates/template-proxy-internal --size=1
gcloud compute instance-groups managed set-named-ports mig-proxy-internal --region=$REGION_B --named-ports=tcp80:80

echo -e "\n${ORANGE_TEXT}[2/7] Creating Firewall Rules...${RESET_FORMAT}"
gcloud compute firewall-rules create fw-allow-hc-proxy-internal --network=lb-network --action=ALLOW --direction=INGRESS --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=tag-proxy-internal --rules=tcp:80
gcloud compute firewall-rules create fw-allow-proxy-subnet-internal --network=lb-network --action=ALLOW --direction=INGRESS --source-ranges=10.129.0.0/23 --target-tags=tag-proxy-internal --rules=tcp:80

echo -e "\n${ORANGE_TEXT}[3/7] Creating Health Check...${RESET_FORMAT}"
gcloud compute health-checks create tcp hc-internal-proxy --region=$REGION_B --port=80

echo -e "\n${ORANGE_TEXT}[4/7] Reserving Internal Static IP...${RESET_FORMAT}"
gcloud compute addresses create ip-internal-proxy --region=$REGION_B --subnet=lb-backend-subnet-region-b --purpose=SHARED_LOADBALANCER_VIP

echo -e "\n${ORANGE_TEXT}[5/7] Creating Backend Service and Attaching MIG...${RESET_FORMAT}"
gcloud compute backend-services create internal-proxy-backend --load-balancing-scheme=INTERNAL_MANAGED --protocol=TCP --region=$REGION_B --health-checks=hc-internal-proxy --health-checks-region=$REGION_B --port-name=tcp80
gcloud compute backend-services add-backend internal-proxy-backend --instance-group=mig-proxy-internal --instance-group-region=$REGION_B --region=$REGION_B

echo -e "\n${ORANGE_TEXT}[6/7] Configuring Frontend...${RESET_FORMAT}"
gcloud compute target-tcp-proxies create target-proxy-internal --region=$REGION_B --backend-service=internal-proxy-backend
gcloud compute forwarding-rules create rule-internal-proxy --region=$REGION_B --load-balancing-scheme=INTERNAL_MANAGED --network=lb-network --subnet=lb-backend-subnet-region-b --address=ip-internal-proxy --target-tcp-proxy=target-proxy-internal --target-tcp-proxy-region=$REGION_B --ports=110

echo -e "\n${ORANGE_TEXT}[7/7] Creating Client VM (Hunting for available zone)...${RESET_FORMAT}"
ZONES=$(gcloud compute zones list --filter="region:$REGION_B" --format="value(name)")
for zone in $ZONES; do
    echo "Attempting to create VM in $zone..."
    if gcloud compute instances create vm-client-internal --zone=$zone --machine-type=e2-micro --network=lb-network --subnet=lb-backend-subnet-region-b --tags=allow-ssh; then
        echo -e "\n${GREEN_TEXT}SUCCESS: VM created in $zone!${RESET_FORMAT}"
        break
    else
        echo "${RED_TEXT}Zone $zone exhausted. Trying next zone...${RESET_FORMAT}"
    fi
done

echo
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   TASK 1 COMPLETE! Go click 'Check my progress' on the lab.      ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@OrbitOfOps${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Please subscribe to Orbit of Ops for more cloud automation guides!${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe!${RESET_FORMAT}"
echo
