#!/bin/bash

clear

# ==============================================================================
# Color Variables & Branding
# ==============================================================================
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}

echo "${CYAN}${BOLD}"
cat << "EOF"
  ____       _     _ _            __    ___            
 / __ \     | |   (_) |          / _|  / _ \           
| |  | |_ __| |__  _| |_   ___  | |_  | | | |_ __  ___ 
| |  | | '__| '_ \| | __| / _ \ |  _| | | | | '_ \/ __|
| |__| | |  | |_) | | |_ | (_) || |   | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__| \___/ |_|    \___/| .__/|___/
                                            | |        
                                            |_|        
EOF
echo "${RESET}"
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP297: Cloud Storage Bucket Lock)... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-east1-c): ${RESET}" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

export BUCKET=$PROJECT_ID

echo "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo "✅ Zone:       ${GREEN}$ZONE${RESET}"
echo "✅ Region:     ${GREEN}$REGION${RESET}"
echo "✅ Bucket:     ${GREEN}$BUCKET${RESET}"
echo ""

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating Storage Bucket...${RESET}"
gsutil mb "gs://$BUCKET"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 2: Defining a 10-second Retention Policy...${RESET}"
gsutil retention set 10s "gs://$BUCKET"
gsutil cp gs://spls/gsp297/dummy_transactions "gs://$BUCKET/"

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 3: Permanently Locking the Retention Policy...${RESET}"
echo "y" | gsutil retention lock "gs://$BUCKET/"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 4: Testing Temporary Holds...${RESET}"
gsutil retention temp set "gs://$BUCKET/dummy_transactions"

# This command is expected to fail because the temp hold is active
echo "${BOLD}${YELLOW}Attempting to delete file (This is EXPECTED to fail)...${RESET}"
gsutil rm "gs://$BUCKET/dummy_transactions" 2>/dev/null || echo "✅ Blocked by Temporary Hold successfully."

echo "${BOLD}${GREEN}Releasing Temporary Hold...${RESET}"
gsutil retention temp release "gs://$BUCKET/dummy_transactions"

echo "${BOLD}${YELLOW}Waiting 12 seconds for the 10s retention policy to officially expire...${RESET}"
sleep 12

echo "${BOLD}${BLUE}Deleting dummy_transactions...${RESET}"
gsutil rm "gs://$BUCKET/dummy_transactions"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 5: Testing Event-based Holds...${RESET}"
gsutil retention event-default set "gs://$BUCKET/"
gsutil cp gs://spls/gsp297/dummy_loan "gs://$BUCKET/"

echo "${BOLD}${GREEN}Releasing Event-based Hold...${RESET}"
gsutil retention event release "gs://$BUCKET/dummy_loan"

echo "${BOLD}${YELLOW}Waiting 12 seconds for the newly calculated retention policy to expire...${RESET}"
sleep 12

echo "${BOLD}${BLUE}Deleting dummy_loan...${RESET}"
gsutil rm "gs://$BUCKET/dummy_loan"

# ==============================================================================
# COMPLETION
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You've successfully completed the lab!${RESET}"
        "${BLUE}Outstanding! Your dedication has brought you success!${RESET}"
        "${MAGENTA}Great work! You're one step closer to mastering this!${RESET}"
        "${RED}Fantastic effort! You've earned this achievement!${RESET}"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}
random_congrats
echo "${CYAN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your manual.${RESET}"
echo "--------------------------------------------------------------------------------"
