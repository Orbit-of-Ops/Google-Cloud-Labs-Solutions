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
echo "${CYAN_TEXT}${BOLD_TEXT}                   SCRIPT 3: TEST FAILOVER (FIXED)                ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

LB_IP_GLOBAL=$(gcloud compute addresses describe ip-alb-global --global --format="value(address)")
echo -e "\n${YELLOW_TEXT}Checking if ALB is fully online (Waiting for HTTP 200 OK)...${RESET_FORMAT}"
echo -e "${ORANGE_TEXT}NOTE: Global ALBs can take 5-10 minutes to fully provision. Please be patient!${RESET_FORMAT}"

# Wait for ALB to be ready
while true; do
  HTTP_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$LB_IP_GLOBAL" || true)
  if [ "$HTTP_STATUS" -eq 200 ]; then 
    echo -e "\n${GREEN_TEXT}SUCCESS: ALB is online (HTTP 200).${RESET_FORMAT}"
    break
  fi
  echo -n "."
  sleep 10
done

echo -e "\n${GREEN_TEXT}Initiating Failover sequence...${RESET_FORMAT}"
mkdir -p ~/.ssh
ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -N "" -q <<< y >/dev/null 2>&1 || true

# Bulletproof method for fetching instance variables using regex and AWK for zone formatting
INSTANCE=$(gcloud compute instances list --filter="name~mig-alb-api-a" --format="value(name)" | head -n 1)
ZONE=$(gcloud compute instances list --filter="name~mig-alb-api-a" --format="value(zone)" | awk -F/ '{print $NF}' | head -n 1)

if [ -z "$INSTANCE" ] || [ -z "$ZONE" ]; then
    echo -e "${RED_TEXT}ERROR: Could not find instance in mig-alb-api-a. Ensure Task 2 completed successfully.${RESET_FORMAT}"
    exit 1
fi

echo -e "${ORANGE_TEXT}Targeting Region A Instance: $INSTANCE in Zone: $ZONE${RESET_FORMAT}"
echo -e "${YELLOW_TEXT}Ensuring Nginx is running to stabilize traffic (using IAP tunnel)...${RESET_FORMAT}"

# Added --tunnel-through-iap to bypass external IP / firewall issues
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --tunnel-through-iap --quiet --command="sudo systemctl start nginx"

echo -e "${YELLOW_TEXT}Waiting 30 seconds for traffic to balance...${RESET_FORMAT}"
sleep 30

echo -e "${RED_TEXT}Stopping Nginx to trigger failover...${RESET_FORMAT}"

# Added --tunnel-through-iap to bypass external IP / firewall issues
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --tunnel-through-iap --quiet --command="sudo systemctl stop nginx"

echo -e "${CYAN_TEXT}Failover triggered. Watching traffic route to Region B...${RESET_FORMAT}"
timeout 25 bash -c '
while true; do
  curl -k -s https://'"$LB_IP_GLOBAL"' | grep "Hello from"
  sleep 0.5
done
'

echo
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   TASK 3 COMPLETE! Go click Check my progress for 100/100.       ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@OrbitOfOps${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Please subscribe to Orbit of Ops for more cloud automation guides.${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe.${RESET_FORMAT}"
echo
