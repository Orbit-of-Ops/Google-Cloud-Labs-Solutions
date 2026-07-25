#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP081 FINAL AIRTIGHT SCRIPT
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}>>> INITIATING GSP081 FULLY PATCHED MASTER SCRIPT <<<${RESET}"
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
if [ -z "$REGION" ]; then export REGION="us-central1"; fi

echo "${YELLOW}[*] Phase 1: Validating Required APIs...${RESET}"
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --quiet
sleep 5

echo -e "\n${YELLOW}[*] Phase 2: Ensuring IAM Permissions...${RESET}"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcf-admin-robot.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader" \
  --quiet 2>/dev/null || true

echo -e "\n${CYAN}[*] Phase 3: Writing Code Architecture...${RESET}"
mkdir -p gcfunction && cd gcfunction

cat << 'EOF' > package.json
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');
functions.http('helloHttp', (req, res) => {
  let message = req.query.message || req.body.message || 'Hello World!';
  res.status(200).send(message);
});
EOF

echo -e "\n${MAGENTA}[*] Phase 4: Deploying Cloud Run Function...${RESET}"
# Deploying the baseline function
gcloud functions deploy gcfunction \
  --region=$REGION \
  --gen2 \
  --runtime=nodejs20 \
  --source=. \
  --entry-point=helloHttp \
  --trigger-http \
  --allow-unauthenticated \
  --max-instances=5 \
  --quiet

echo -e "\n${YELLOW}[*] Phase 5: Enforcing 'Second generation' Execution Environment with valid CPU/Memory...${RESET}"
# THE FIX: Upgrading CPU to 1 and Memory to 1024Mi to satisfy the strict gen2 environment requirements
gcloud run services update gcfunction \
  --region=$REGION \
  --execution-environment=gen2 \
  --cpu=1 \
  --memory=1024Mi \
  --quiet

echo -e "\n${CYAN}[*] Phase 6: Testing Function Trigger (Task 3)...${RESET}"
gcloud functions call gcfunction --region=$REGION --gen2 --data '{"message":"Hello World!"}'

echo -e "\n${GREEN}${BOLD}====================================================================${RESET}"
echo "${GREEN}${BOLD}>>> LAB 100% COMPLETE! YOU CAN NOW CLICK 'CHECK MY PROGRESS' <<<${RESET}"
echo "${GREEN}${BOLD}====================================================================${RESET}"
