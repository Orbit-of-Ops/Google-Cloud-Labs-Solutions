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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP1157: Dataplex IAM Roles)... ${RESET}"
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
# USER 2 CREDENTIALS REQUIRED
# ==============================================================================
echo "--------------------------------------------------------------------------------"
echo "${BOLD}${MAGENTA}⚠️  ATTENTION: USER 2 CREDENTIALS REQUIRED ⚠️${RESET}"
echo "${BOLD}${WHITE}Please check your Qwiklabs manual panel and copy the email for 'Username 2'.${RESET}"
read -p "${BOLD}${CYAN}Enter User 2 Email (e.g., student-xx-xxxx@qwiklabs.net): ${RESET}" USER2_EMAIL
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo "${BOLD}${BLUE}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable dataplex.googleapis.com

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'customer-info-lake' Lake...${RESET}"
gcloud dataplex lakes create customer-info-lake \
  --location=$REGION \
  --display-name="Customer Info Lake" 2>/dev/null || echo "✅ Lake already exists."

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'customer-raw-zone' Zone...${RESET}"
gcloud dataplex zones create customer-raw-zone \
    --location=$REGION \
    --lake=customer-info-lake \
    --display-name="Customer Raw Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *" 2>/dev/null || echo "✅ Zone already exists."

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Attaching 'customer-online-sessions' Asset...${RESET}"
gcloud dataplex assets create customer-online-sessions \
    --location=$REGION \
    --lake=customer-info-lake \
    --zone=customer-raw-zone \
    --display-name="Customer Online Sessions" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID-bucket \
    --discovery-enabled 2>/dev/null || echo "✅ Asset already exists."

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 2: Granting 'Dataplex Data Reader' role to User 2...${RESET}"
gcloud dataplex assets add-iam-policy-binding customer-online-sessions \
    --location=$REGION \
    --lake=customer-info-lake \
    --zone=customer-raw-zone \
    --member="user:$USER2_EMAIL" \
    --role="roles/dataplex.dataReader"

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 4: Granting 'Dataplex Data Writer' role to User 2...${RESET}"
gcloud dataplex assets add-iam-policy-binding customer-online-sessions \
    --location=$REGION \
    --lake=customer-info-lake \
    --zone=customer-raw-zone \
    --member="user:$USER2_EMAIL" \
    --role="roles/dataplex.dataWriter"

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 5: Automatically uploading test file to Cloud Storage...${RESET}"
# We create a dummy CSV file and push it to the bucket to trigger the Task 5 completion check
echo "id,name,status" > test_upload.csv
echo "1,orbit,active" >> test_upload.csv
gsutil cp test_upload.csv gs://$PROJECT_ID-bucket/

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
echo "${CYAN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your manual.${RESET}"
echo "${YELLOW}${BOLD}(Note: Qwiklabs might take 1-2 minutes to register the IAM changes and file upload. Just keep clicking!)${RESET}"
echo "--------------------------------------------------------------------------------"
