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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP1143: Dataplex Qwik Start)... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS & AUTO-FETCH
# ==============================================================================
echo "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project & Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-central1-a): ${RESET}" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

echo "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo "✅ Region:     ${GREEN}$REGION${RESET}"
echo ""

# ==============================================================================
# PART 1: CREATION 
# ==============================================================================
echo "${BOLD}${BLUE}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable dataplex.googleapis.com

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'sensors' Lake...${RESET}"
gcloud dataplex lakes create sensors \
  --location=$REGION \
  --display-name="sensors"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 2: Creating 'temperature-raw-data' Zone...${RESET}"
gcloud dataplex zones create temperature-raw-data \
    --location=$REGION \
    --lake=sensors \
    --display-name="temperature raw data" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 3: Creating Cloud Storage Bucket...${RESET}"
gsutil mb -l $REGION gs://$PROJECT_ID

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 3: Attaching 'measurements' Asset...${RESET}"
gcloud dataplex assets create measurements \
    --location=$REGION \
    --lake=sensors \
    --zone=temperature-raw-data \
    --display-name="measurements" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID \
    --discovery-enabled

# ==============================================================================
# PAUSE FOR VERIFICATION (CRITICAL)
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
echo "${BG_MAGENTA}${WHITE}${BOLD} ⚠️  STOP HERE AND CHECK YOUR PROGRESS ⚠️  ${RESET}"
echo "${CYAN}${BOLD}Do NOT press Enter yet! If you continue, the resources will be deleted and you will get 0 points.${RESET}"
echo ""
echo "${WHITE}${BOLD}Please go to your Qwiklabs manual and click 'Check my progress' for:${RESET}"
echo "${GREEN}  ✅ Task 1 (Create a lake)${RESET}"
echo "${GREEN}  ✅ Task 2 (Add a zone)${RESET}"
echo "${GREEN}  ✅ Task 3 (Attach an asset)${RESET}"
echo "--------------------------------------------------------------------------------"
read -p "${YELLOW}${BOLD}Once you have 75/100 points, press [ENTER] to delete the resources and finish the lab...${RESET}"

# ==============================================================================
# PART 2: DELETION (TASK 4)
# ==============================================================================
echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 4: Commencing resource deletion...${RESET}"

echo "${BOLD}${BLUE}[Orbit of Ops] Detaching 'measurements' Asset...${RESET}"
gcloud dataplex assets delete measurements \
    --location=$REGION \
    --lake=sensors \
    --zone=temperature-raw-data \
    --quiet

echo "${BOLD}${BLUE}[Orbit of Ops] Deleting 'temperature-raw-data' Zone...${RESET}"
gcloud dataplex zones delete temperature-raw-data \
    --location=$REGION \
    --lake=sensors \
    --quiet

echo "${BOLD}${BLUE}[Orbit of Ops] Deleting 'sensors' Lake...${RESET}"
gcloud dataplex lakes delete sensors \
    --location=$REGION \
    --quiet

# ==============================================================================
# COMPLETION
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
function random_congrats() {
    MESSAGES=(
        "Congratulations For Completing The Lab! Keep up the great work!"
        "Well done! Your hard work and effort have paid off!"
        "Amazing job! You've successfully completed the lab!"
        "Outstanding! Your dedication has brought you success!"
        "Great work! You're one step closer to mastering this!"
        "Fantastic effort! You've earned this achievement!"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${GREEN}${BOLD}${MESSAGES[$RANDOM_INDEX]}${RESET}"
}
random_congrats
echo "${CYAN}${BOLD}You can now click 'Check my progress' for Task 4 to get 100/100!${RESET}"
echo "--------------------------------------------------------------------------------"
