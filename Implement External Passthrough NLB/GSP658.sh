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

BG_GREEN=`tput setab 2`
BG_BLACK=`tput setab 0`

BOLD=`tput bold`
UNDERLINE=`tput smul`
RESET=`tput sgr0`

#----------------------------------------------------START--------------------------------------------------#

echo "${CYAN}${BOLD}======================================================================${RESET}"
echo "${CYAN}${BOLD}                     🚀  ORBIT OF OPS  🚀                            ${RESET}"
echo "${CYAN}${BOLD}======================================================================${RESET}"
echo "${WHITE}${BOLD} Operation:     ${YELLOW}Network Load Balancer Deployment${RESET}"
echo "${WHITE}${BOLD} Status:        ${YELLOW}Executing Full Session Deployment${RESET}"
echo "${CYAN}${BOLD}----------------------------------------------------------------------${RESET}"
echo ""

# Auto-fetch project and region/zone
echo "${YELLOW}${BOLD}[1/5] ORBIT OF OPS 🚀 | Fetching Project Infrastructure...${RESET}"
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute instances list --format="value(zone)" --limit=1 | sed 's/-[a-z]$//')
ZONE=$(gcloud compute instances list --format="value(zone)" --limit=1)
VM1=$(gcloud compute instances list --format="value(name)" | grep -v "1$" | head -1)
VM2=$(gcloud compute instances list --format="value(name)" | grep "1$" | head -1)

# Fallback: list all VMs and pick first two
if [ -z "$VM1" ] || [ -z "$VM2" ]; then
  VMS=($(gcloud compute instances list --format="value(name)"))
  VM1="${VMS[0]}"
  VM2="${VMS[1]}"
fi

echo "${GREEN}✔ Project ID:${RESET} ${WHITE}$PROJECT_ID${RESET}"
echo "${GREEN}✔ Region Linked:${RESET} ${WHITE}$REGION${RESET}"
echo "${GREEN}✔ Zone Linked:${RESET} ${WHITE}$ZONE${RESET}"
echo "${GREEN}✔ Backend VM 1:${RESET} ${WHITE}$VM1${RESET}"
echo "${GREEN}✔ Backend VM 2:${RESET} ${WHITE}$VM2${RESET}"
echo "${CYAN}${BOLD}----------------------------------------------------------------------${RESET}"
echo ""

# ─── TASK 1: Instance Groups ───────────────────────────────────────────────────

echo "${MAGENTA}${BOLD}[2/5] ORBIT OF OPS 🚀 | Creating Unmanaged Instance Groups...${RESET}"

echo "${WHITE}Allocating web-server-1 (VM: $VM1)...${RESET}"
gcloud compute instance-groups unmanaged create web-server-1 \
  --zone="$ZONE" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

gcloud compute instance-groups unmanaged add-instances web-server-1 \
  --zone="$ZONE" \
  --instances="$VM1" \
  --project="$PROJECT_ID" --quiet

echo "${GREEN}✔ web-server-1 configured successfully${RESET}"

echo "${WHITE}Allocating web-server-2 (VM: $VM2)...${RESET}"
gcloud compute instance-groups unmanaged create web-server-2 \
  --zone="$ZONE" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

gcloud compute instance-groups unmanaged add-instances web-server-2 \
  --zone="$ZONE" \
  --instances="$VM2" \
  --project="$PROJECT_ID" --quiet

echo "${GREEN}✔ web-server-2 configured successfully${RESET}"
echo ""

# ─── TASK 2: Health Check & IP ─────────────────────────────────────────────────

echo "${BLUE}${BOLD}[3/5] ORBIT OF OPS 🚀 | Provisioning Network Services...${RESET}"

echo "${WHITE}Creating TCP Health Check (Port 80)...${RESET}"
gcloud compute health-checks create tcp basic-http-check \
  --region="$REGION" \
  --port=80 \
  --project="$PROJECT_ID" --quiet 2>/dev/null

echo "${WHITE}Reserving Static External VIP...${RESET}"
gcloud compute addresses create network-lb-ip \
  --region="$REGION" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

LB_IP=$(gcloud compute addresses describe network-lb-ip \
  --region="$REGION" \
  --format="value(address)" \
  --project="$PROJECT_ID")

echo "${GREEN}✔ Health Check active${RESET}"
echo "${GREEN}✔ Static VIP reserved: ${BOLD}$LB_IP${RESET}"
echo ""

# ─── TASK 2: Backend Service ──────────────────────────────────────────────────

echo "${YELLOW}${BOLD}[4/5] ORBIT OF OPS 🚀 | Constructing Backend Service...${RESET}"

gcloud compute backend-services create network-lb-backend-service \
  --protocol=TCP \
  --region="$REGION" \
  --health-checks=basic-http-check \
  --health-checks-region="$REGION" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

echo "${WHITE}Mapping Instance Groups to Backend Service...${RESET}"

gcloud compute backend-services add-backend network-lb-backend-service \
  --instance-group=web-server-1 \
  --instance-group-zone="$ZONE" \
  --region="$REGION" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

gcloud compute backend-services add-backend network-lb-backend-service \
  --instance-group=web-server-2 \
  --instance-group-zone="$ZONE" \
  --region="$REGION" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

echo "${GREEN}✔ Backend service synchronized with web clusters${RESET}"
echo ""

# ─── MANUAL INTERVENTION ──────────────────────────────────────────────────────
echo "${BG_BLACK}${RED}${BOLD} ⚠️ MANUAL STEP REQUIRED IN GOOGLE CLOUD CONSOLE ⚠️ ${RESET}"
echo "${CYAN}----------------------------------------------------------------------${RESET}"
echo "${WHITE}Name:         ${BOLD}network-lb-backend-service${RESET}"
echo "${WHITE}Health Check: ${BOLD}basic-http-check${RESET}"
echo "${WHITE}Backends:     ${BOLD}web-server-1 and web-server-2${RESET}"
echo "${WHITE}Frontend IP:  ${BOLD}network-lb-ip${RESET}"
echo "${WHITE}Port:         ${BOLD}80${RESET}"
echo "${CYAN}----------------------------------------------------------------------${RESET}"
echo "${YELLOW}Click this link to open your Load Balancer Dashboard:${RESET}"
echo "${UNDERLINE}https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=$PROJECT_ID${RESET}"
echo ""
read -p "${MAGENTA}${BOLD}➜ Create the load balancer via the UI, then press [ENTER] to continue script... ${RESET}"

echo ""
# ─── TASK 2: Target Pool + Forwarding Rule ────────────────────────────────────

echo "${CYAN}${BOLD}[5/5] ORBIT OF OPS 🚀 | Finalizing Target Pools & Rules...${RESET}"

echo "${WHITE}Creating Target Pool & Attaching Instances...${RESET}"
gcloud compute target-pools create network-lb-target-pool \
  --region="$REGION" \
  --project="$PROJECT_ID" --quiet 2>/dev/null

gcloud compute target-pools add-instances network-lb-target-pool \
  --instances="$VM1","$VM2" \
  --instances-zone="$ZONE" \
  --region="$REGION" \
  --project="$PROJECT_ID" --quiet

echo "${WHITE}Creating Frontend Forwarding Rule...${RESET}"
gcloud compute forwarding-rules create network-lb-forwarding-rule \
  --region="$REGION" \
  --ports=80 \
  --address=network-lb-ip \
  --target-pool=network-lb-target-pool \
  --project="$PROJECT_ID" --quiet 2>/dev/null

echo "${GREEN}✔ Target Pool populated${RESET}"
echo "${GREEN}✔ Forwarding Rule active${RESET}"
echo ""

# ─── Final Completion Message ─────────────────────────────────────────────────
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}           🚀 ORBIT OF OPS | ARCHITECTURE DEPLOYMENT SUCCESSFUL 🚀    ${RESET}"
echo "${BG_GREEN}${BLACK}${BOLD}======================================================================${RESET}"
echo ""
echo "${WHITE}The operation is 100% complete! You can now securely verify your lab progress.${RESET}"
echo ""
echo "${CYAN}${BOLD} Thank you for choosing Orbit Of Ops!                                 ${RESET}"
echo "${CYAN}${BOLD} Don't forget to like the video and subscribe to stay updated!        ${RESET}"
echo "${CYAN}${UNDERLINE}https://www.youtube.com/@OrbitOfOps${RESET}"
echo "${BLUE}${BOLD}======================================================================${RESET}"
