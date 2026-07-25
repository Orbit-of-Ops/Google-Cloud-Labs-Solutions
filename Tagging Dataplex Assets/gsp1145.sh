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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP1145: Knowledge Catalog Aspects)... ${RESET}"
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
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo "${BOLD}${BLUE}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'orders-lake' Lake...${RESET}"
gcloud dataplex lakes create orders-lake \
  --location=$REGION \
  --display-name="Orders Lake" 2>/dev/null || echo "✅ Lake already exists."

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'customer-curated-zone' Zone...${RESET}"
gcloud dataplex zones create customer-curated-zone \
    --location=$REGION \
    --lake=orders-lake \
    --display-name="Customer Curated Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=CURATED \
    --discovery-enabled \
    --discovery-schedule="0 * * * *" 2>/dev/null || echo "✅ Zone already exists."

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Attaching 'customer-details-dataset' Asset...${RESET}"
gcloud dataplex assets create customer-details-dataset \
    --location=$REGION \
    --lake=orders-lake \
    --zone=customer-curated-zone \
    --display-name="Customer Details Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$PROJECT_ID/datasets/customers \
    --discovery-enabled 2>/dev/null || echo "✅ Asset already exists."

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 2: Creating 'Protected Data Aspect' Type...${RESET}"
cat > aspect_template.json <<EOF
{
  "name": "protected_data_template",
  "type": "record",
  "recordFields": [
    {
      "name": "protected_data_flag",
      "type": "enum",
      "index": 1,
      "annotations": {
        "displayName": "Protected Data Flag"
      },
      "constraints": {
        "required": true
      },
      "enumValues": [
        { "name": "Yes", "index": 1 },
        { "name": "No", "index": 2 }
      ]
    }
  ]
}
EOF

gcloud dataplex aspect-types create protected-data-aspect \
  --location=$REGION \
  --display-name="Protected Data Aspect" \
  --metadata-template-file-name=aspect_template.json 2>/dev/null || echo "✅ Aspect Type already exists."


# ==============================================================================
# COMPLETION & MANUAL UI GUIDE FOR TASK 3
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
function random_congrats() {
    MESSAGES=(
        "Tasks 1 and 2 Completed Successfully! You're almost there!"
        "Great work so far! Infrastructure deployed successfully!"
        "Backend automated! Just a few clicks left to finish up!"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${GREEN}${BOLD}${MESSAGES[$RANDOM_INDEX]}${RESET}"
}
random_congrats
echo "--------------------------------------------------------------------------------"
echo "${BG_MAGENTA}${BOLD} ⚠️  TASK 3 MUST BE COMPLETED IN THE *SEARCH* UI ⚠️  ${RESET}"
echo "${YELLOW}${BOLD}Do NOT go through 'Manage Lakes'. You must use the Search bar to get the new 'Aspects' UI.${RESET}"
echo ""
echo "${CYAN}${BOLD}1. Go to: ${WHITE}Navigation Menu > Dataplex > Search${RESET}"
echo "${CYAN}${BOLD}2. Type 'customer_details' in the search bar and click it.${RESET}"
echo "${YELLOW}${BOLD}   *(If it says 'Failed to load', DO NOT PANIC. It just means the backend is still scanning.${RESET}"
echo "${YELLOW}${BOLD}   Wait exactly 2 minutes, refresh the page, and try clicking it again).*${RESET}"
echo ""
echo "${MAGENTA}${BOLD}[Part A - Main Entry]${RESET}"
echo "${CYAN}${BOLD}3. Scroll down to 'Optional aspects' -> Click 'Add' -> Select 'Protected Data Aspect' -> Set 'Yes' -> Save.${RESET}"
echo ""
echo "${MAGENTA}${BOLD}[Part B - Columns]${RESET}"
echo "${CYAN}${BOLD}4. Click the 'Schema' tab at the top.${RESET}"
echo "${CYAN}${BOLD}5. Check the boxes for exactly these 9 columns:${RESET}"
echo "${WHITE}${BOLD}   [zip, state, last_name, country, email, latitude, first_name, city, longitude]${RESET}"
echo "${CYAN}${BOLD}6. Click 'Add aspect' -> Select 'Protected Data Aspect' -> Set 'Yes' -> Save.${RESET}"
echo "--------------------------------------------------------------------------------"
