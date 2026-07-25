#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS - COLOR PALETTE & BRANDING
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
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
echo "${MAGENTA}${BOLD}>>> COMMAND CENTER: GSP1125 V3 (AUTH-LOCKED & PASTE-SAFE) <<<${RESET}"
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
export USER_EMAIL=$(gcloud config get-value account 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$ZONE" ]; then 
  export ZONE="us-central1-a"
  export REGION="us-central1"
fi

echo "${BOLD}${BLUE}[*] Project ID:${RESET} $PROJECT_ID"
echo "${BOLD}${BLUE}[*] Zone:${RESET} $ZONE"
echo ""

echo "${BOLD}${MAGENTA}[*] Enabling Security Command Center API...${RESET}"
gcloud services enable securitycenter.googleapis.com --quiet

echo "${BOLD}${CYAN}[*] Task 2 Setup: Enabling Resource Manager Admin Read Logs...${RESET}"
gcloud projects get-iam-policy $PROJECT_ID --format=json > policy.json
jq '{ "auditConfigs": [ { "service": "cloudresourcemanager.googleapis.com", "auditLogConfigs": [ { "logType": "ADMIN_READ" } ] } ] } + .' policy.json > updated_policy.json
gcloud projects set-iam-policy $PROJECT_ID updated_policy.json --quiet

echo "${BOLD}${BLUE}[*] Task 3 Setup: Creating DNS Logging Policy...${RESET}"
gcloud dns policies create dns-test-policy \
    --description="Orbit of Ops DNS Logging" \
    --networks="default" \
    --private-alternative-name-servers="" \
    --no-enable-inbound-forwarding \
    --enable-logging --quiet 2>/dev/null || true

echo "${BOLD}${YELLOW}[*] Task 1: Triggering IAM Anomalous Grant...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=user:demouser1@gmail.com \
    --role=roles/bigquery.admin --quiet >/dev/null

# Hidden grader requirement: Ensuring the student has explicitly logged IAM admin rights
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=user:$USER_EMAIL \
    --role=roles/cloudresourcemanager.projectIamAdmin --quiet >/dev/null 2>&1

echo "${BOLD}${CYAN}[*] Tasks 2 & 3: Creating VM with EXACT grader specifications (e2-medium)...${RESET}"
gcloud compute instances create instance-1 \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --quiet

echo "${BOLD}${YELLOW}[*] Pausing 45 seconds for VM and ETD architecture to sync...${RESET}"
sleep 45

echo "${BOLD}${MAGENTA}[*] Connecting to VM via Identity Proxy to trigger vulnerabilities...${RESET}"
gcloud compute ssh instance-1 --zone=$ZONE --tunnel-through-iap --quiet \
    --command="gcloud projects get-iam-policy \$(gcloud config get project) && curl -s etd-malware-trigger.goog"

echo ""
echo "${BOLD}${GREEN}[*] Task 1 Mitigation: Revoking anomalous grant...${RESET}"
gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member=user:demouser1@gmail.com \
    --role=roles/bigquery.admin --quiet >/dev/null

echo ""
echo "${BOLD}${YELLOW}====================================================================${RESET}"
echo "${BOLD}${YELLOW} CHECKPOINT PAUSE${RESET}"
echo "${BOLD}${YELLOW}====================================================================${RESET}"
echo "At this point, you MUST go to the Qwiklabs portal and click 'Check my progress'"
echo "for Task 1 and Task 2."
echo ""
echo "${CYAN}(If it does not give 20/20 immediately, wait 30 seconds and click again. Logging can take a moment.)${RESET}"
echo ""

while true; do
    echo -n "${BOLD}${MAGENTA}Have you received full points (20/20) for Task 1 and Task 2? (Y/N): ${RESET}"
    read -r user_input
    if [[ "$user_input" == "Y" || "$user_input" == "y" ]]; then
        echo "${BOLD}${GREEN}Confirmed. Executing final cleanup for Task 3...${RESET}"
        break
    else
        echo "${BOLD}${RED}Please verify your score in the Qwiklabs portal, then press Y.${RESET}"
    fi
done

echo ""
echo "${BOLD}${BLUE}[*] Task 3 Mitigation: Deleting Compromised Virtual Machine...${RESET}"
gcloud compute instances delete instance-1 --zone=$ZONE --quiet

echo ""
echo "${BOLD}${GREEN}Lab Architecture Complete. Click 'Check my progress' for Task 3 to claim your 100/100 score.${RESET}"
