#!/bin/bash
clear

# ==============================================================================
# Orbit of Ops Branding & Colors
# ==============================================================================
BOLD=$(tput bold)
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
MAGENTA=$(tput setaf 5)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}====================================================${RESET}"
echo "${CYAN}${BOLD}    ORBIT OF OPS: Sensitive Data Protection         ${RESET}"
echo "${CYAN}${BOLD}    Discovery & IAM Conditional Access              ${RESET}"
echo "${CYAN}${BOLD}====================================================${RESET}"
echo ""

# ==============================================================================
# Initialization
# ==============================================================================
echo "${YELLOW}Initializing and fetching project details...${RESET}"
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export CURRENT_USER=$(gcloud config get-value account)

if [ -z "$PROJECT_ID" ]; then
    echo "${RED}Error: Could not fetch Project ID. Run 'gcloud auth login' and try again.${RESET}"
    exit 1
fi

echo "${GREEN}Orbit of Ops: Project ID detected: ${PROJECT_ID}${RESET}"
echo "${GREEN}Orbit of Ops: Project Number detected: ${PROJECT_NUMBER}${RESET}"
echo ""

# Auto-detect Username 2 for Task 4 display
export USER2=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="value(bindings.members)" | grep "user:.*@qwiklabs.net" | sed 's/user://' | grep -v "$CURRENT_USER" | head -n 1)
if [ -z "$USER2" ]; then
    USER2="[The other student-...@qwiklabs.net account]"
fi

# ==============================================================================
# TASK 1: MANUAL DISCOVERY SETUP
# ==============================================================================
echo "${YELLOW}${BOLD}=== ORBIT OF OPS: TASK 1 (MANUAL SETUP) ===${RESET}"
echo "To ensure the grader correctly registers your scan, complete Task 1 in the UI:"
echo ""
echo "1. Hold CTRL (or CMD) and click this link to open a new tab:"
echo "   ${CYAN}https://console.cloud.google.com/security/sensitive-data-protection/discovery${RESET}"
echo "2. Under 'BigQuery', click ${BOLD}'Enable'${RESET}."
echo "3. Click ${BOLD}Continue${RESET} through Discovery type, Scope, Schedules, and Inspection Template."
echo "4. Under 'Add actions':"
echo "   - Check the box for ${BOLD}'Publish to Security Command Center'${RESET}"
echo "   - Check the box for ${BOLD}'Save data profile copies to BigQuery'${RESET}"
echo "     > Set Dataset ID to: ${BOLD}bq_discovery${RESET}"
echo "     > Set Table ID to: ${BOLD}data_profiles${RESET}"
echo "5. Click ${BOLD}Continue${RESET}."
echo "6. Set Location to: ${BOLD}us (multiple regions in United States)${RESET} -> Click Continue."
echo "7. Set Display Name to: ${BOLD}BigQuery Discovery${RESET}"
echo "8. ${RED}${BOLD}CRUCIAL:${RESET} Check the box for ${BOLD}'Create scan in paused mode'${RESET}."
echo "9. Click ${BOLD}Create${RESET}, then ${BOLD}Create configuration${RESET}."
echo ""
echo "Now go to your Qwiklabs manual and click 'Check my progress' for Task 1."
echo "${YELLOW}=====================================================${RESET}"
echo ""
read -p "${BOLD}Press [ENTER] only AFTER you get the 20/20 green check for Task 1...${RESET}"
echo ""

# ==============================================================================
# TASK 2: AUTOMATED TAG CREATION & IAM BINDING
# ==============================================================================
echo "${CYAN}${BOLD}=== ORBIT OF OPS: TASK 2 (AUTOMATED) ===${RESET}"
echo "${YELLOW}Creating Tag Key 'sensitivity-level'...${RESET}"
gcloud resource-manager tags keys create sensitivity-level \
    --parent=projects/$PROJECT_NUMBER \
    --description="Sensitivity level tagged as low, moderate, high, and unknown" > /dev/null 2>&1

TAG_KEY_ID=$(gcloud resource-manager tags keys list --parent="projects/${PROJECT_NUMBER}" --format="value(NAME)")

echo "${YELLOW}Creating Tag Values (low, moderate, high, unknown)...${RESET}"
gcloud resource-manager tags values create low --parent=$TAG_KEY_ID --description="low-sensitivity" > /dev/null 2>&1
gcloud resource-manager tags values create moderate --parent=$TAG_KEY_ID --description="moderate-sensitivity" > /dev/null 2>&1
gcloud resource-manager tags values create high --parent=$TAG_KEY_ID --description="high-sensitivity" > /dev/null 2>&1
gcloud resource-manager tags values create unknown --parent=$TAG_KEY_ID --description="unknown-sensitivity" > /dev/null 2>&1

echo "${YELLOW}Assigning tagUser role to Sensitive Data Protection Service Account...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:service-$PROJECT_NUMBER@dlp-api.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.tagUser" > /dev/null 2>&1

echo "${GREEN}${BOLD}Task 2 Setup Complete!${RESET}"
echo "Go to your Qwiklabs manual and click 'Check my progress' for Task 2."
echo "${YELLOW}=====================================================${RESET}"
echo ""
read -p "${BOLD}Press [ENTER] only AFTER you get the green check for Task 2...${RESET}"
echo ""

# ==============================================================================
# TASK 3: MANUAL SCAN UPDATE
# ==============================================================================
echo "${YELLOW}${BOLD}=== ORBIT OF OPS: TASK 3 (MANUAL UPDATE) ===${RESET}"
echo "You must now map the tags created in Task 2 to the paused scan."
echo ""
echo "1. On the Discovery page UI, click the 3 dots next to 'BigQuery Discovery' and select ${BOLD}Edit${RESET}."
echo "2. Under 'Add actions', check ${BOLD}'Tag resources'${RESET} and check all 4 sensitivity boxes."
echo "3. Copy and paste these exact values into the UI fields:"
echo "   - High:     ${CYAN}${PROJECT_ID}/sensitivity-level/high${RESET}"
echo "   - Moderate: ${CYAN}${PROJECT_ID}/sensitivity-level/moderate${RESET}"
echo "   - Low:      ${CYAN}${PROJECT_ID}/sensitivity-level/low${RESET}"
echo "   - Unknown:  ${CYAN}${PROJECT_ID}/sensitivity-level/unknown${RESET}"
echo "4. Check the final two boxes:"
echo "   - 'When a tag is applied to a resource, lower the data risk...'"
echo "   - 'Tag a resource when it is profiled for the first time.'"
echo "5. Click ${BOLD}Save${RESET}, then ${BOLD}Confirm edit${RESET}, then click ${BOLD}Resume Scan${RESET}."
echo ""
echo "Go to your Qwiklabs manual and click 'Check my progress' for Task 3."
echo "${YELLOW}=====================================================${RESET}"
echo ""
read -p "${BOLD}Press [ENTER] only AFTER you get the green check for Task 3...${RESET}"
echo ""

# ==============================================================================
# TASK 4: MANUAL IAM CONDITIONS & BQ TAGGING
# ==============================================================================
echo "${CYAN}${BOLD}=== ORBIT OF OPS: TASK 4 (MANUAL WORKAROUND) ===${RESET}"
echo "Due to strict grader constraints and Qwiklabs limits, do this in the UI:"
echo ""
echo "${MAGENTA}--- Part A: Conditional IAM for Username 2 ---${RESET}"
echo "1. Go to ${BOLD}IAM & Admin > IAM${RESET}."
echo "2. Locate Username 2: ${CYAN}$USER2${RESET}"
echo "3. Click the pencil icon (Edit) next to them."
echo "4. Delete the ${BOLD}'Viewer'${RESET} role (click the trash can icon)."
echo "5. Click 'Add another role' -> select ${BOLD}Basic > Browser${RESET}."
echo "6. Next to the 'BigQuery Data Viewer' role, click ${BOLD}Add IAM condition${RESET}:"
echo "   - Title: ${BOLD}Low Sensitivity Data Access Only${RESET}"
echo "   - Condition type: ${BOLD}Tag${RESET}  |  Operator: ${BOLD}has value${RESET}"
echo "   - Value path: ${CYAN}${PROJECT_ID}/sensitivity-level/low${RESET}"
echo "7. Click Save, then Save again."
echo ""
echo "${MAGENTA}--- Part B: Tag the BigQuery Dataset ---${RESET}"
echo "1. Go to ${BOLD}BigQuery${RESET} in the console."
echo "2. Expand your project in the Explorer pane and click the ${BOLD}'damaged_car_image_info'${RESET} dataset."
echo "3. Click ${BOLD}Edit details${RESET} (the pencil icon in the dataset info panel)."
echo "4. Under 'Tags', click ${BOLD}Select scope > Select current project${RESET}."
echo "5. Set Key 1 to: ${BOLD}sensitivity-level${RESET}"
echo "6. Set Value 1 to: ${BOLD}low${RESET}"
echo "7. Click Save."
echo ""
echo "${GREEN}${BOLD}ORBIT OF OPS: All Tasks Complete!${RESET}"
echo "${YELLOW}WAIT 5 MINUTES before clicking 'Check my progress' for Task 4.${RESET}"
echo "${CYAN}${BOLD}====================================================${RESET}"
echo ""
