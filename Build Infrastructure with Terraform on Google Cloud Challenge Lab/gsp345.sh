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
echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP345)... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo "${BOLD}${YELLOW}[Orbit of Ops] Checking required lab variables...${RESET}"

if [[ -z "$BUCKET" ]]; then
    read -p "${BOLD}${CYAN}Enter your BUCKET Name: ${RESET}" BUCKET
    export BUCKET
fi

if [[ -z "$INSTANCE" ]]; then
    read -p "${BOLD}${CYAN}Enter your 3rd INSTANCE Name: ${RESET}" INSTANCE
    export INSTANCE
fi

if [[ -z "$VPC" ]]; then
    read -p "${BOLD}${CYAN}Enter your VPC Name: ${RESET}" VPC
    export VPC
fi
echo ""

# Auto-fetch Zone & Region
echo "${BOLD}${BLUE}[Orbit of Ops] Auto-fetching Zone and Region...${RESET}"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo "${BOLD}${RED}⚠️ Could not auto-detect the zone.${RESET}"
    read -p "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-central1-a): ${RESET}" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "✅ Zone: ${GREEN}$ZONE${RESET} | Region: ${GREEN}$REGION${RESET}"
echo ""

# ==============================================================================
# SCRIPT EXECUTION STEPS
# ==============================================================================

# Step 1: Install Terraform
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 1: Installing Terraform...${RESET}"
cat <<'EOF' > ~/.customize_environment
# Set up HashiCorp repository and install Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF
bash ~/.customize_environment
echo ""

# Fetch Existing Instance IDs
echo "${BOLD}${CYAN}[Orbit of Ops] Fetching existing instance IDs...${RESET}"
instances_output=$(gcloud compute instances list --format="value(id)")
IFS=$'\n' read -r -d '' instance_id_1 instance_id_2 <<< "$instances_output"

export INSTANCE_ID_1=$instance_id_1
export INSTANCE_ID_2=$instance_id_2
echo "✅ Instance 1 ID: $INSTANCE_ID_1"
echo "✅ Instance 2 ID: $INSTANCE_ID_2"
echo ""

# Step 2: Initialize Terraform Workspace
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 2: Setting up Terraform workspace & files...${RESET}"
cd ~
touch main.tf variables.tf
mkdir -p modules/instances modules/storage
touch modules/instances/{instances.tf,outputs.tf,variables.tf}
touch modules/storage/{storage.tf,outputs.tf,variables.tf}

cat > variables.tf <<EOF_CP
variable "region" {
 default = "$REGION"
}

variable "zone" {
 default = "$ZONE"
}

variable "project_id" {
 default = "$PROJECT_ID"
}
EOF_CP

cat > main.tf <<EOF_CP
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "instances" {
  source     = "./modules/instances"
}
EOF_CP

terraform init 
echo ""

# Step 3: Configure Instances & Import Infrastructure
echo "${BOLD}${BLUE}[Orbit of Ops] Step 3: Configuring instances and importing infra...${RESET}"
cd modules/instances/
cat > instances.tf <<EOF_CP
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "n1-standard-1"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "n1-standard-1"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}
EOF_CP

cd ~
terraform import module.instances.google_compute_instance.tf-instance-1 $INSTANCE_ID_1
terraform import module.instances.google_compute_instance.tf-instance-2 $INSTANCE_ID_2

terraform plan
terraform apply -auto-approve
echo ""

# Step 4: Configure Storage Backend
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 4: Configuring Storage Backend...${RESET}"
cd modules/storage/
cat > storage.tf <<EOF_CP
resource "google_storage_bucket" "storage-bucket" {
  name          = "$BUCKET"
  location      = "US"
  force_destroy = true
  uniform_bucket_level_access = true
}
EOF_CP

cd ~
cat > main.tf <<EOF_CP
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "instances" {
  source     = "./modules/instances"
}

module "storage" {
  source     = "./modules/storage"
}
EOF_CP

terraform init
terraform apply -auto-approve

cat > main.tf <<EOF_CP
terraform {
  backend "gcs" {
    bucket  = "$BUCKET"
    prefix  = "terraform/state"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "instances" {
  source     = "./modules/instances"
}

module "storage" {
  source     = "./modules/storage"
}
EOF_CP

# Migrate state non-interactively
echo "yes" | terraform init
echo ""

# Step 5: Update Infrastructure & Add 3rd Instance
echo "${BOLD}${CYAN}[Orbit of Ops] Step 5: Updating instances and adding $INSTANCE...${RESET}"
cd modules/instances/
cat > instances.tf <<EOF_CP
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}

resource "google_compute_instance" "$INSTANCE" {
  name         = "$INSTANCE"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}
EOF_CP
cd ~

terraform init
terraform apply -auto-approve
echo ""

# Step 6: Taint and Destroy 3rd Instance
echo "${BOLD}${YELLOW}[Orbit of Ops] Step 6: Tainting & removing $INSTANCE...${RESET}"
terraform taint module.instances.google_compute_instance.$INSTANCE
terraform plan
terraform apply -auto-approve

cd modules/instances/
cat > instances.tf <<EOF_CP
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}
EOF_CP

cd ~
terraform apply -auto-approve
echo ""

# Step 7: Apply VPC Module & Configure Subnets
echo "${BOLD}${BLUE}[Orbit of Ops] Step 7: Applying VPC module from Registry...${RESET}"
cat > main.tf <<EOF_CP
terraform {
  backend "gcs" {
    bucket  = "$BUCKET"
    prefix  = "terraform/state"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "instances" {
  source     = "./modules/instances"
}

module "storage" {
  source     = "./modules/storage"
}

module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 6.0.0"

    project_id   = "$PROJECT_ID"
    network_name = "$VPC"
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = "subnet-01"
            subnet_ip             = "10.10.10.0/24"
            subnet_region         = "$REGION"
        },
        {
            subnet_name           = "subnet-02"
            subnet_ip             = "10.10.20.0/24"
            subnet_region         = "$REGION"
            subnet_private_access = "true"
            subnet_flow_logs      = "true"
            description           = "Orbit of Ops Lab Subnet"
        },
    ]
}
EOF_CP

terraform init
terraform apply -auto-approve

cd modules/instances/
cat > instances.tf <<EOF_CP
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "$VPC"
    subnetwork = "subnet-01"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "$VPC"
    subnetwork = "subnet-02"
  }
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}
EOF_CP

cd ~
terraform init
terraform apply -auto-approve
echo ""

# Step 8: Configure Firewall Rules
echo "${BOLD}${MAGENTA}[Orbit of Ops] Step 8: Configuring Firewall Rules...${RESET}"
cat >> main.tf <<EOF_CP
resource "google_compute_firewall" "tf-firewall"{
  name    = "tf-firewall"
  network = "projects/$PROJECT_ID/global/networks/$VPC"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags = ["web"]
  source_ranges = ["0.0.0.0/0"]
}
EOF_CP

terraform init
terraform apply -auto-approve
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

# Cleanup temporary lab shell scripts (leaves Terraform files intact for review)
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
