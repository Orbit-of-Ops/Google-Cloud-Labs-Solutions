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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution... ${RESET}"
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

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-central1-a): ${RESET}" ZONE
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
echo "${BG_MAGENTA}${BOLD}Enabling APIs and granting initial IAM roles...${RESET}"

gcloud services enable \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

mkdir -p vuln-scan && cd vuln-scan

echo "${BOLD}${BLUE}[Orbit of Ops] Creating vulnerable Docker image and app (Debian 11)...${RESET}"
# FIXED: Updated base image from debian10 to debian11 per lab instructions
cat > ./Dockerfile << EOF
FROM gcr.io/google-appengine/debian11

# System
RUN apt update && apt install python3-pip -y

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==1.1.4  
RUN pip3 install gunicorn==20.1.0  

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 --timeout 0 main:app
EOF

cat > ./main.py << EOF
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    name = os.environ.get("NAME", "Worlds")
    return "Hello {}!".format(name)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

cat > ./cloudbuild.yaml << EOF
steps:
# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']
EOF

gcloud builds submit

echo "${BG_MAGENTA}${BOLD}Setting up Artifact Registry...${RESET}"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Docker repository"

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

cat > ./cloudbuild.yaml << EOF
steps:
# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

# push to artifact registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image']

images:
  - $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
EOF

gcloud builds submit

echo "${BOLD}${YELLOW}[Orbit of Ops] Scanning image for vulnerabilities...${RESET}"
docker build -t $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image .

gcloud artifacts docker images scan \
    $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image \
    --format="value(response.scan)" > scan_id.txt

cat scan_id.txt

gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt)

export SEVERITY=CRITICAL

gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt) --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq ${SEVERITY}; then echo "Failed vulnerability check for ${SEVERITY} level"; else echo "No ${SEVERITY} Vulnerabilities found"; fi

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

echo "${BG_MAGENTA}${BOLD}Running CI/CD pipeline with Vulnerability Scan (Expect failure)...${RESET}"
cat > ./cloudbuild.yaml << EOF
steps:

# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

#Run a vulnerability scan at _SECURITY level
- id: scan
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    (gcloud artifacts docker images scan \
    $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image \
    --location us \
    --format="value(response.scan)") > /workspace/scan_id.txt

#Analyze the result of the scan
- id: severity check
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
      gcloud artifacts docker images list-vulnerabilities \$(cat /workspace/scan_id.txt) \
      --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
      then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo "No CRITICAL vulnerability found, congrats !" && exit 0; fi

#Retag
- id: "retag"
  name: 'gcr.io/cloud-builders/docker'
  args: ['tag',  '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']


#pushing to artifact registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

images:
  - $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
EOF

gcloud builds submit || true

echo "${BOLD}${GREEN}[Orbit of Ops] Fixing vulnerabilities (Switching to Alpine)...${RESET}"
cat > ./Dockerfile << EOF
FROM python:3.8-alpine 

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==2.1.0
RUN pip3 install gunicorn==20.1.0
RUN pip3 install Werkzeug==2.2.2

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 main:app
EOF

echo "${BG_MAGENTA}${BOLD}Running CI/CD pipeline with Secure Image (Expect pass)...${RESET}"
gcloud builds submit

# ==============================================================================
# COMPLETION & CLEANUP
# ==============================================================================
echo "--------------------------------------------------------------------------------"
echo "${RED}${BOLD}Congratulations${RESET} ${WHITE}${BOLD}for${RESET} ${GREEN}${BOLD}Completing the Lab !!!${RESET}"
echo "--------------------------------------------------------------------------------"
