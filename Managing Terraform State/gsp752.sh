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

BOLD=$(tput bold)
RESET=$(tput sgr0)

TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}

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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP752)... ${RESET}"
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
    read -p "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-west1-b): ${RESET}" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

echo "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo "✅ Zone:       ${GREEN}$ZONE${RESET}"
echo "✅ Region:     ${GREEN}$REGION${RESET}"
echo ""

# ==============================================================================
# SCRIPT EXECUTION STEPS
# ==============================================================================

# Step 1: Install Terraform & Fix Cloud Shell Wrapper Issue
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 1: Installing Terraform...${RESET}"
cat <<'EOF' > ~/.customize_environment
# Added --yes flag to gpg to prevent "Enter new filename:" prompts
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF
bash ~/.customize_environment

# FIX: Remove the dummy wrapper so the system uses the real HashiCorp binary
sudo rm -f /usr/local/bin/terraform
echo "✅ Terraform installation verified: $(terraform version -v)"
echo ""

# Step 2: Configure Local Backend Workspace
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 2: Setting up initial main.tf with Local Backend...${RESET}"
cd ~
touch main.tf

cat > main.tf <<EOF_CP
provider "google" {
  project     = "$PROJECT_ID"
  region      = "$REGION"
}

resource "google_storage_bucket" "test-bucket-for-state" {
  name        = "$PROJECT_ID"
  location    = "US"
  uniform_bucket_level_access = true
}

terraform {
  backend "local" {
    path = "terraform/state/terraform.tfstate"
  }
}
EOF_CP

# Step 3: Initialize and Apply Local Infrastructure
echo "${BOLD}${BLUE}[Orbit of Ops] Step 3: Initializing and applying local configuration...${RESET}"
terraform init
terraform apply -auto-approve
echo ""

# Step 4: Configure Cloud Storage (GCS) Backend
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 4: Reconfiguring main.tf for Cloud Storage Backend...${RESET}"
cat > main.tf <<EOF_CP
provider "google" {
  project     = "$PROJECT_ID"
  region      = "$REGION"
}

resource "google_storage_bucket" "test-bucket-for-state" {
  name        = "$PROJECT_ID"
  location    = "US"
  uniform_bucket_level_access = true
}

terraform {
  backend "gcs" {
    bucket  = "$PROJECT_ID"
    prefix  = "terraform/state"
  }
}
EOF_CP

# Step 5: Migrate State Non-Interactively
echo "${BOLD}${CYAN}[Orbit of Ops] Step 5: Migrating local state to GCS bucket...${RESET}"
echo "yes" | terraform init -migrate-state
echo ""

# Step 6: Simulate Out-of-Band Cloud Changes & Refresh State
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 6: Updating bucket labels and refreshing state...${RESET}"
gcloud storage buckets update gs://$PROJECT_ID --update-labels=key=value

echo "${BLUE}Running terraform refresh...${RESET}"
terraform refresh

echo "${BLUE}Verifying infrastructure state alignment:${RESET}"
terraform show
echo ""

# ==============================================================================
# COMPLETION & CLEANUP
# ==============================================================================

function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You've successfully completed the lab!${RESET}"
        "${BLUE}Outstanding! Your dedication has brought you success!${RESET}"
        "${MAGENTA}Great work! You're one step closer to mastering this!${RESET}"
        "${RED}Fantastic effort! You've earned this achievement!${RESET}"
        "${CYAN}Congratulations! Your persistence has paid off brilliantly!${RESET}"
    )

    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}

echo "--------------------------------------------------------------------------------"
random_congrats
echo -e "\n"

# Cleanup temporary lab shell scripts
remove_files() {
    echo "${CYAN}${BOLD}[Orbit of Ops] Running Shell Script Cleanup...${RESET}"
    for file in *; do
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            if [[ -f "$file" ]]; then
                rm "$file"
                echo " 🗑️  File removed: $file"
            fi
        fi
    done
    echo "${GREEN}${BOLD}Cleanup Complete! Have a great day.${RESET}"
}

remove_files
