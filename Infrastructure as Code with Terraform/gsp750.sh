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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP750: Build, Change, Destroy)... ${RESET}"
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
# MAIN SCRIPT EXECUTION
# ==============================================================================
echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

# Fix Cloud Shell Terraform Wrapper Issue First
echo "${BOLD}${MAGENTA}[Orbit of Ops] Installing Terraform & Applying Cloud Shell Fix...${RESET}"
cat <<'EOF' > ~/.customize_environment
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF
bash ~/.customize_environment
sudo rm -f /usr/local/bin/terraform
echo "✅ Terraform installation verified: $(terraform version -v)"
echo ""

echo "${BOLD}${BLUE}[Orbit of Ops] Step 1: Building initial network infrastructure...${RESET}"
touch main.tf
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}
EOF

terraform init
terraform apply --auto-approve

echo "${BOLD}${BLUE}[Orbit of Ops] Step 2: Adding VM Instance (with Debian 12 fix)...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}
EOF
terraform apply --auto-approve

echo "${BOLD}${BLUE}[Orbit of Ops] Step 3: Modifying Instance Tags...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  tags         = ["web", "dev"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}
EOF
terraform apply --auto-approve

echo "${BOLD}${BLUE}[Orbit of Ops] Step 4: Making Destructive Changes (Image Update)...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  tags         = ["web", "dev"]
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}
EOF
terraform apply --auto-approve

# ==============================================================================
# PAUSE FOR PROGRESS CHECK
# ==============================================================================
echo "--------------------------------------------------------------------------------"
echo "${BOLD}${MAGENTA}⚠️  ATTENTION: ACTION REQUIRED! ⚠️${RESET}"
echo "${BOLD}${WHITE}The lab requires us to completely destroy the infrastructure next.${RESET}"
echo "${BOLD}${CYAN}Please go to the Qwiklabs manual and click the FIRST THREE 'Check my progress' buttons now!${RESET}"
echo "  1. Create resources in Terraform"
echo "  2. Change the infrastructure"
echo "  3. Make destructive changes"
echo "--------------------------------------------------------------------------------"
read -p "${BOLD}${GREEN}Press [ENTER] ONLY after you have received your points for those three sections...${RESET}"

echo "${BOLD}${RED}[Orbit of Ops] Destroying infrastructure as per lab instructions...${RESET}"
terraform destroy --auto-approve

echo "${BOLD}${BLUE}[Orbit of Ops] Step 5: Recreating infrastructure and planning static IP dependency...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  tags         = ["web", "dev"]
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_address" "vm_static_ip" {
  name = "terraform-static-ip"
}
EOF
terraform plan

echo "${BOLD}${BLUE}[Orbit of Ops] Step 6: Applying explicit dependencies...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  tags         = ["web", "dev"]
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
	nat_ip = google_compute_address.vm_static_ip.address
    }
  }
}

resource "google_compute_address" "vm_static_ip" {
  name = "terraform-static-ip"
}
EOF
terraform plan -out static_ip
terraform apply "static_ip"

echo "${BOLD}${BLUE}[Orbit of Ops] Step 7: Creating dependent Cloud Storage bucket...${RESET}"
cat  > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {
  version = "3.5.0"
  project = "$PROJECT_ID"
  region  = "$REGION"
  zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  tags         = ["web", "dev"]
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
	nat_ip = google_compute_address.vm_static_ip.address
    }
  }
}

resource "google_compute_address" "vm_static_ip" {
  name = "terraform-static-ip"
}

# New resource for the storage bucket our application will use.
resource "google_storage_bucket" "example_bucket" {
  name     = "$PROJECT_ID"
  location = "US"
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_compute_instance" "another_instance" {
  # Tells Terraform that this VM instance must be created only after the
  # storage bucket has been created.
  depends_on = [google_storage_bucket.example_bucket]
  name         = "terraform-instance-2"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    access_config {
    }
  }
}
EOF
terraform plan
terraform apply --auto-approve

# ==============================================================================
# COMPLETION
# ==============================================================================
echo "--------------------------------------------------------------------------------"
echo "${RED}${BOLD}Congratulations${RESET} ${WHITE}${BOLD}for${RESET} ${GREEN}${BOLD}Completing the Lab !!!${RESET}"
echo "${CYAN}${BOLD}You can now click the final two 'Check my progress' buttons in the manual!${RESET}"
echo "--------------------------------------------------------------------------------"
