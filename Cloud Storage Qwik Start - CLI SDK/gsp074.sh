#!/bin/bash

clear

# ==============================================================================
# Color Variables
# ==============================================================================
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

BG_BLACK=$(tput setab 0)
BG_RED=$(tput setab 1)
BG_GREEN=$(tput setab 2)
BG_YELLOW=$(tput setab 3)
BG_BLUE=$(tput setab 4)
BG_MAGENTA=$(tput setab 5)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

BOLD=$(tput bold)
RESET=$(tput sgr0)

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors for the dynamic banner
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

# ==============================================================================
# ORBIT OF OPS BRANDING BANNER
# ==============================================================================
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
echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# SCRIPT EXECUTION STEPS
# ==============================================================================

# Step 1: Bulletproof Region Fetcher
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 1: Auto-fetching Compute Region...${RESET}"

# Fetch the region using project metadata and silence the Qwiklabs 404 IAM errors
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null | tail -n 1)

# Fallback just in case the region is blank
if [[ -z "$REGION" ]]; then
    echo "${BOLD}${RED}⚠️  Could not auto-detect the region.${RESET}"
    read -p "${BOLD}${CYAN}Please enter the lab Region (e.g., us-central1): ${RESET}" REGION
    export REGION
fi

echo "✅ Successfully acquired Region: ${BOLD}${GREEN}$REGION${RESET}"
gcloud config set compute/region $REGION
echo ""

# Step 2: Create Cloud Storage Bucket
echo "${BOLD}${BLUE}[Orbit of Ops] Step 2: Creating Cloud Storage Bucket...${RESET}"
gsutil mb gs://$DEVSHELL_PROJECT_ID
echo ""

# Step 3: Download Sample Image
echo "${BOLD}${CYAN}[Orbit of Ops] Step 3: Downloading sample image (Ada Lovelace)...${RESET}"
curl https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg
echo ""

# Step 4: Upload Image to Bucket
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 4: Uploading image to Cloud Storage bucket...${RESET}"
gsutil cp ada.jpg gs://$DEVSHELL_PROJECT_ID
echo ""

# Step 5: Download Image from Bucket to Local
echo "${BOLD}${GREEN}[Orbit of Ops] Step 5: Downloading image back from the bucket...${RESET}"
gsutil cp -r gs://$DEVSHELL_PROJECT_ID/ada.jpg .
echo ""

# Step 6: Copy Image to a Folder Inside the Bucket
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 6: Copying image into a folder within the bucket...${RESET}"
gsutil cp gs://$DEVSHELL_PROJECT_ID/ada.jpg gs://$DEVSHELL_PROJECT_ID/image-folder/
echo ""

# Step 7: Update ACL to Make Image Publicly Readable
echo "${BOLD}${RED}[Orbit of Ops] Step 7: Updating ACL to make the image public...${RESET}"
gsutil acl ch -u AllUsers:R gs://$DEVSHELL_PROJECT_ID/ada.jpg
echo ""

# ==============================================================================
# COMPLETION & CLEANUP
# ==============================================================================

# Function to display a random congratulatory message
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You've successfully completed the lab!${RESET}"
        "${BLUE}Outstanding! Your dedication has brought you success!${RESET}"
        "${MAGENTA}Great work! You're one step closer to mastering this!${RESET}"
        "${RED}Fantastic effort! You've earned this achievement!${RESET}"
        "${CYAN}Congratulations! Your persistence has paid off brilliantly!${RESET}"
        "${GREEN}Bravo! You've completed the lab with flying colors!${RESET}"
        "${YELLOW}Excellent job! Your commitment is inspiring!${RESET}"
        "${BLUE}You did it! Keep striving for more successes like this!${RESET}"
        "${MAGENTA}Kudos! Your hard work has turned into a great accomplishment!${RESET}"
        "${RED}You've smashed it! Completing this lab shows your dedication!${RESET}"
        "${CYAN}Impressive work! You're making great strides!${RESET}"
        "${GREEN}Well done! This is a big step towards mastering the topic!${RESET}"
        "${YELLOW}You nailed it! Every step you took led you to success!${RESET}"
        "${BLUE}Exceptional work! Keep this momentum going!${RESET}"
        "${MAGENTA}Fantastic! You've achieved something great today!${RESET}"
        "${RED}Incredible job! Your determination is truly inspiring!${RESET}"
        "${CYAN}Well deserved! Your effort has truly paid off!${RESET}"
        "${GREEN}You've got this! Every step was a success!${RESET}"
        "${YELLOW}Nice work! Your focus and effort are shining through!${RESET}"
        "${BLUE}Superb performance! You're truly making progress!${RESET}"
        "${MAGENTA}Top-notch! Your skill and dedication are paying off!${RESET}"
        "${RED}Mission accomplished! This success is a reflection of your hard work!${RESET}"
        "${CYAN}You crushed it! Keep pushing towards your goals!${RESET}"
        "${GREEN}You did a great job! Stay motivated and keep learning!${RESET}"
        "${YELLOW}Well executed! You've made excellent progress today!${RESET}"
        "${BLUE}Remarkable! You're on your way to becoming an expert!${RESET}"
        "${MAGENTA}Keep it up! Your persistence is showing impressive results!${RESET}"
        "${RED}This is just the beginning! Your hard work will take you far!${RESET}"
        "${CYAN}Terrific work! Your efforts are paying off in a big way!${RESET}"
        "${GREEN}You've made it! This achievement is a testament to your effort!${RESET}"
        "${YELLOW}Excellent execution! You're well on your way to mastering the subject!${RESET}"
        "${BLUE}Wonderful job! Your hard work has definitely paid off!${RESET}"
        "${MAGENTA}You're amazing! Keep up the awesome work!${RESET}"
        "${RED}What an achievement! Your perseverance is truly admirable!${RESET}"
        "${CYAN}Incredible effort! This is a huge milestone for you!${RESET}"
        "${GREEN}Awesome! You've done something incredible today!${RESET}"
        "${YELLOW}Great job! Keep up the excellent work and aim higher!${RESET}"
        "${BLUE}You've succeeded! Your dedication is your superpower!${RESET}"
        "${MAGENTA}Congratulations! Your hard work has brought great results!${RESET}"
        "${RED}Fantastic work! You've taken a huge leap forward today!${RESET}"
        "${CYAN}You're on fire! Keep up the great work!${RESET}"
        "${GREEN}Well deserved! Your efforts have led to success!${RESET}"
        "${YELLOW}Incredible! You've achieved something special!${RESET}"
        "${BLUE}Outstanding performance! You're truly excelling!${RESET}"
        "${MAGENTA}Terrific achievement! Keep building on this success!${RESET}"
        "${RED}Bravo! You've completed the lab with excellence!${RESET}"
        "${CYAN}Superb job! You've shown remarkable focus and effort!${RESET}"
        "${GREEN}Amazing work! You're making impressive progress!${RESET}"
        "${YELLOW}You nailed it again! Your consistency is paying off!${RESET}"
        "${BLUE}Incredible dedication! Keep pushing forward!${RESET}"
        "${MAGENTA}Excellent work! Your success today is well earned!${RESET}"
        "${RED}You've made it! This is a well-deserved victory!${RESET}"
        "${CYAN}Wonderful job! Your passion and hard work are shining through!${RESET}"
        "${GREEN}You've done it! Keep up the hard work and success will follow!${RESET}"
        "${YELLOW}Great execution! You're truly mastering this!${RESET}"
        "${BLUE}Impressive! This is just the beginning of your journey!${RESET}"
        "${MAGENTA}You've achieved something great today! Keep it up!${RESET}"
        "${RED}You've made remarkable progress! This is just the start!${RESET}"
    )

    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}

# Display a random congratulatory message
echo "--------------------------------------------------------------------------------"
random_congrats
echo -e "\n"

# Change to home directory for cleanup
cd || exit

remove_files() {
    echo "${CYAN}${BOLD}[Orbit of Ops] Running Workspace Cleanup...${RESET}"
    # Loop through all files in the current directory
    for file in *; do
        # Check if the file name starts with "gsp", "arc", "ada", or "shell"
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* || "$file" == ada* ]]; then
            # Check if it's a regular file (not a directory)
            if [[ -f "$file" ]]; then
                # Remove the file and echo the file name
                rm "$file"
                echo " 🗑️  File removed: $file"
            fi
        fi
    done
    echo "${GREEN}${BOLD}Cleanup Complete! Have a great day.${RESET}"
}

remove_files
