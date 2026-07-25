#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS - BRANDING & COLORS (PASTE-SAFE)
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

BG_MAGENTA=$(tput setab 5)
BG_BLUE=$(tput setab 4)

BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo "${RESET}"
echo "${MAGENTA}${BOLD}>>> COMMAND CENTER: GSP382 CHALLENGE LAB INITIATED <<<${RESET}"
echo ""

# ==============================================================================
# AUTHENTICATION LOCK
# ==============================================================================
echo "${BOLD}${YELLOW}[*] Verifying Cloud Shell Authentication...${RESET}"
gcloud auth list
echo "${CYAN}(If a popup appeared asking to Authorize, please click it now.)${RESET}"
sleep 3
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$ZONE" ]; then 
  export ZONE="us-east1-b"
  export REGION="us-east1"
fi
export BUCKET_NAME="scc-export-bucket-$PROJECT_ID"

echo "${BOLD}${BLUE}[*] Project ID:${RESET} $PROJECT_ID"
echo "${BOLD}${BLUE}[*] Region:${RESET} $REGION"
echo ""

# ==============================================================================
# TASK 2: STATIC MUTE RULES
# ==============================================================================
echo "${BOLD}${MAGENTA}[*] Task 2: Creating Static Mute Rules for Cymbal Bank...${RESET}"

gcloud scc muteconfigs create muting-flow-log-findings \
  --project=$PROJECT_ID \
  --location=global \
  --description="Rule for muting VPC Flow Logs" \
  --filter="category=\"FLOW_LOGS_DISABLED\"" \
  --type=STATIC --quiet 2>/dev/null || true

gcloud scc muteconfigs create muting-audit-logging-findings \
  --project=$PROJECT_ID \
  --location=global \
  --description="Rule for muting audit logs" \
  --filter="category=\"AUDIT_LOGGING_DISABLED\"" \
  --type=STATIC --quiet 2>/dev/null || true

gcloud scc muteconfigs create muting-admin-sa-findings \
  --project=$PROJECT_ID \
  --location=global \
  --description="Rule for muting admin service account findings" \
  --filter="category=\"ADMIN_SERVICE_ACCOUNT\"" \
  --type=STATIC --quiet 2>/dev/null || true

# ==============================================================================
# TASK 3: FIX HIGH VULNERABILITY FINDINGS (FIREWALL RULES)
# ==============================================================================
echo "${BOLD}${CYAN}[*] Task 3: Patching Open SSH and RDP Vulnerabilities...${RESET}"

gcloud compute firewall-rules delete default-allow-rdp --quiet 2>/dev/null || true
gcloud compute firewall-rules create default-allow-rdp \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:3389 \
  --description="Allow RDP from IAP" \
  --priority=65534 --quiet 2>/dev/null || true

gcloud compute firewall-rules delete default-allow-ssh --quiet 2>/dev/null || true
gcloud compute firewall-rules create default-allow-ssh \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:22 \
  --description="Allow SSH from IAP" \
  --priority=65534 --quiet 2>/dev/null || true

# ==============================================================================
# TASK 4 & 5 SETUP: STATIC IP & CLOUD STORAGE
# ==============================================================================
echo "${BOLD}${YELLOW}[*] Task 4 Setup: Reserving Static External IP for cls-vm...${RESET}"
export VM_EXT_IP=$(gcloud compute instances describe cls-vm --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
gcloud compute addresses create static-ip --addresses=$VM_EXT_IP --region=$REGION --quiet 2>/dev/null || true

echo "${BOLD}${BLUE}[*] Task 5 Setup: Provisioning Export Bucket...${RESET}"
gsutil mb -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || true
gsutil uniformbucketlevelaccess set off gs://$BUCKET_NAME/ 2>/dev/null || true

echo "${BOLD}${GREEN}Automated architecture deployment complete. Proceeding to final UI phases.${RESET}"
echo ""

# ==============================================================================
# EMBEDDED UI INSTRUCTIONS
# ==============================================================================
echo "${BG_MAGENTA}${WHITE}${BOLD}                                                                            ${RESET}"
echo "${BG_MAGENTA}${WHITE}${BOLD}  🚀 ORBIT OF OPS: REQUIRED MANUAL UI STEPS TO COMPLETE CHALLENGE LAB       ${RESET}"
echo "${BG_MAGENTA}${WHITE}${BOLD}                                                                            ${RESET}"
echo ""

echo "${BOLD}${GREEN}--- TASKS 2 & 3 ---${RESET}"
echo "You can now safely click 'Check my progress' for Task 2 and Task 3 in the portal."
echo ""

echo "${BOLD}${CYAN}--- TASK 4: WEB SECURITY SCANNER ---${RESET}"
echo "1. Go to ${BOLD}Security > Web Security Scanner${RESET} in the console."
echo "2. Click ${BOLD}+ New Scan${RESET}."
echo "3. Starting URL: Copy and paste exactly this link: ${GREEN}http://$VM_EXT_IP:8080${RESET}"
echo "4. Leave all other settings as default and click ${BOLD}Save${RESET}."
echo "5. On the next screen, click the ${BOLD}Run${RESET} button."
echo "6. Wait for the scan status to change to 'Finished' (This takes a few minutes)."
echo "   ${YELLOW}* Click 'Check My Progress' for Task 4 once the scan finishes. *${RESET}"
echo ""

echo "${BOLD}${CYAN}--- TASK 5: EXPORT FINDINGS TO STORAGE ---${RESET}"
echo "1. Go to ${BOLD}Security > Security Command Center > Findings${RESET}."
echo "2. Click the ${BOLD}Export${RESET} button near the top > ${BOLD}Cloud Storage${RESET}."
echo "3. Project name: Select your current Project ID."
echo "4. Export path: Click Browse, select ${BOLD}$BUCKET_NAME${RESET}, set filename to ${BOLD}findings.jsonl${RESET}, click ${BOLD}Select${RESET}."
echo "5. Format: ${BOLD}JSONL${RESET} | Time Range: ${BOLD}All time${RESET}."
echo "6. Click ${BOLD}Export${RESET}."
echo "   ${YELLOW}* Click 'Check My Progress' for Task 5. *${RESET}"
echo ""
echo "${BOLD}${GREEN}All parameters configured. Awaiting mission success confirmation.${RESET}"
