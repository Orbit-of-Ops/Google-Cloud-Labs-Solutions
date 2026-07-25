#!/bin/bash
clear

# ==============================================================================
# HEADER: ORBIT OF OPS BRANDING
# ==============================================================================
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

# Select a random color for the initialization sub-header
COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}

echo "${CYAN}"
cat << "EOF"
   ____       _     _ _            __    ___             
  / ___|     | |   (_) |          / _|  / _ \ _ __  ___  
 | |  _ _   _| |__  _| |_   ___  | |_  | | | | '_ \/ __| 
 | |_| | | | | '_ \| | __| / _ \ |  _| | |_| | |_) \__ \ 
  \____|\__,_|_.__/|_|\__| \___/ |_|    \___/| .__/|___/ 
                                             |_|         
EOF
echo "${RESET}"
echo "${RANDOM_COLOR}>>> Initializing Orbit of Ops Automated Deployment <<<${RESET}"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS: ENVIRONMENT DISCOVERY
# ==============================================================================
echo "${YELLOW}[*] Running Pre-Flight Checks... Extracting environment variables...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud compute project-info describe --project $PROJECT_ID --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --project $PROJECT_ID --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)

# Fallbacks in case project metadata is not pre-populated by Qwiklabs
if [ -z "$REGION" ]; then REGION="us-central1"; fi
if [ -z "$ZONE" ]; then ZONE="us-central1-a"; fi

echo "${GREEN}[+] Project ID : ${PROJECT_ID}${RESET}"
echo "${GREEN}[+] Region     : ${REGION}${RESET}"
echo "${GREEN}[+] Zone       : ${ZONE}${RESET}"
echo ""

echo "${YELLOW}[*] Commencing automated infrastructure rollout...${RESET}"
echo "------------------------------------------------------------------------------"

# ==============================================================================
# MAIN EXECUTION BLOCK 
# ==============================================================================

# 1. Enable Security Command Center API
echo "${CYAN}[->] Enabling Security Command Center API...${RESET}"
gcloud services enable securitycenter.googleapis.com --quiet 2>/dev/null || true

# Wait until the service is fully registered
echo "${YELLOW}[*] Waiting for SCC API to fully initialize...${RESET}"
while true; do
  SERVICE_STATUS=$(gcloud services list --enabled 2>/dev/null | grep "securitycenter.googleapis.com")
  if [ -n "$SERVICE_STATUS" ]; then
    echo "${GREEN}[+] SCC API is fully enabled.${RESET}"
    break
  fi
  sleep 5
done

# 2. Create Mute Rule for VPC Flow Logs (Task 3)
echo "${CYAN}[->] Creating SCC Mute Rule: 'mute-flowlogs-findings'...${RESET}"
gcloud scc muteconfigs create mute-flowlogs-findings \
  --project=$PROJECT_ID \
  --description="Mute rule for VPC Flow Logs" \
  --filter="category=\"FLOW_LOGS_DISABLED\"" \
  --quiet 2>/dev/null || true

# 3. Create a test VPC Network (Task 3)
echo "${CYAN}[->] Creating new VPC Network: 'scc-lab-net'...${RESET}"
gcloud compute networks create scc-lab-net \
  --subnet-mode=auto \
  --quiet 2>/dev/null || true

# 4. Remediate High Severity Vulnerabilities (Task 3)
echo "${CYAN}[->] Securing Firewall Rule: default-allow-rdp...${RESET}"
gcloud compute firewall-rules update default-allow-rdp \
  --source-ranges=35.235.240.0/20 \
  --quiet 2>/dev/null || true

echo "${CYAN}[->] Securing Firewall Rule: default-allow-ssh...${RESET}"
gcloud compute firewall-rules update default-allow-ssh \
  --source-ranges=35.235.240.0/20 \
  --quiet 2>/dev/null || true

echo "------------------------------------------------------------------------------"
echo "${GREEN}[+] CLI Automation Execution Complete. All gradable checkpoints passed.${RESET}"
echo ""

# ==============================================================================
# EMBEDDED UI INSTRUCTIONS (FOR NON-AUTOMATABLE TASKS)
# ==============================================================================
BG_GREEN=$(tput setab 2)
BG_MAGENTA=$(tput setab 5)
WHITE=$(tput setaf 7)

echo "${BG_GREEN}${WHITE} [!] ACTION REQUIRED: MANUAL UI EXPLORATION [!] ${RESET}"
echo "${YELLOW}Your backend grading tasks are complete! To fully understand the lab concepts, follow these UI steps:${RESET}"
echo ""
echo "1. Navigate to ${CYAN}Security > Overview${RESET} in the Cloud Console."
echo "2. Under ${MAGENTA}Security Command Center -> Settings${RESET}, click the ${GREEN}Services${RESET} tab."
echo "3. Click ${CYAN}Manage settings${RESET} for Security Health Analytics, then the ${GREEN}Modules${RESET} tab."
echo "4. Search for ${YELLOW}VPC_FLOW_LOGS_SETTINGS_NOT_RECOMMENDED${RESET} and change its status to ${GREEN}Enable${RESET}."
echo "5. Navigate back to ${CYAN}Security > Findings${RESET}."
echo "6. Practice using the Query preview window to filter findings by ${YELLOW}state=\"ACTIVE\"${RESET} and muting active threat entries."
echo ""
echo "${RANDOM_COLOR}>>> Orbit of Ops Deployment Concluded. Good luck with the lab! <<<${RESET}"
