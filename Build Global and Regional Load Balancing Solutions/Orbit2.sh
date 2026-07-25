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
echo "${CYAN_TEXT}${BOLD_TEXT}               SCRIPT 2: GLOBAL EXTERNAL ALB                      ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter REGION_A (e.g., us-central1): ${RESET_FORMAT}" RAW_REGION_A
export REGION_A=$(echo "$RAW_REGION_A" | tr -d '\r ')
RAW_REGION_B=$(gcloud compute instances list --filter="name:vm-client-internal" --format="value(zone)" | sed 's/-[a-z]$//')
export REGION_B=$(echo "$RAW_REGION_B" | tr -d '\r ')

echo -e "\n${ORANGE_TEXT}[1/6] Creating Regional MIGs (A & B)...${RESET_FORMAT}"
gcloud compute instance-groups managed create mig-alb-api-a --template=template-alb-api --size=1 --region=$REGION_A
gcloud compute instance-groups managed set-named-ports mig-alb-api-a --named-ports=http80:80 --region=$REGION_A

gcloud compute instance-groups managed create mig-alb-api-b --template=template-alb-api --size=1 --region=$REGION_B
gcloud compute instance-groups managed set-named-ports mig-alb-api-b --named-ports=http80:80 --region=$REGION_B

echo -e "\n${ORANGE_TEXT}[2/6] Creating Global Firewall Rule...${RESET_FORMAT}"
ALB_NETWORK=$(gcloud compute instance-templates describe template-alb-api --format="value(properties.networkInterfaces[0].network)" | awk -F/ '{print $NF}')
gcloud compute firewall-rules create fw-allow-health-check-and-proxy --network=$ALB_NETWORK --direction=INGRESS --action=ALLOW --rules=tcp:80 --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=tag-alb-api

echo -e "\n${ORANGE_TEXT}[3/6] Creating Health Check & Backend Service...${RESET_FORMAT}"
gcloud compute health-checks create http http-check-alb --global --port=80
gcloud compute backend-services create service-alb-global --global --protocol=HTTP --health-checks=http-check-alb --port-name=http80

echo -e "\n${ORANGE_TEXT}[4/6] Adding Backends with Rate Limiting (RPS=1)...${RESET_FORMAT}"
gcloud compute backend-services add-backend service-alb-global --global --instance-group=mig-alb-api-a --instance-group-region=$REGION_A --balancing-mode=RATE --max-rate-per-instance=1
gcloud compute backend-services add-backend service-alb-global --global --instance-group=mig-alb-api-b --instance-group-region=$REGION_B --balancing-mode=RATE --max-rate-per-instance=1

echo -e "\n${ORANGE_TEXT}[5/6] Generating SSL Certificate...${RESET_FORMAT}"
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1 -subj "/CN=example.com" 2>/dev/null
gcloud compute ssl-certificates create cert-self-signed --certificate=cert.pem --private-key=key.pem --global

echo -e "\n${ORANGE_TEXT}[6/6] Configuring Global Frontend...${RESET_FORMAT}"
gcloud compute addresses create ip-alb-global --global
gcloud compute url-maps create url-map-alb --default-service=service-alb-global
gcloud compute target-https-proxies create https-proxy-alb --url-map=url-map-alb --ssl-certificates=cert-self-signed
gcloud compute forwarding-rules create https-forwarding-rule --global --target-https-proxy=https-proxy-alb --ports=443 --address=ip-alb-global

echo
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   TASK 2 PROVISIONED! Wait 3-5 mins before checking progress.    ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@OrbitOfOps${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Please subscribe to Orbit of Ops for more cloud automation guides!${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe!${RESET_FORMAT}"
echo
