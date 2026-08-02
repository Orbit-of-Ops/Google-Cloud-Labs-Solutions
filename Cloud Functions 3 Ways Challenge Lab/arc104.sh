#!/bin/bash
clear

# ==============================================================================
# Color Variables & Orbit of Ops Branding
# ==============================================================================
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
BOLD='\e[1m'
RESET='\e[0m'

echo -e "${CYAN}${BOLD}"
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
echo -e "${RESET}"
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (ARC104)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & HARDCODED VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Configuring Environment Variables...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export REGION="us-east4"
export STORAGE_FUNCTION="cs-monitor"
export HTTP_FUNCTION="http-responder"
export BUCKET_NAME="$PROJECT_ID"
export BUCKET_URI="gs://$PROJECT_ID"

gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID:       ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Project Number:   ${GREEN}$PROJECT_NUMBER${RESET}"
echo -e "✅ Enforced Region:  ${GREEN}$REGION${RESET}"
echo -e "✅ Storage Function: ${GREEN}$STORAGE_FUNCTION${RESET}"
echo -e "✅ HTTP Function:    ${GREEN}$HTTP_FUNCTION${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Enabling required APIs (This takes ~1 minute)...${RESET}"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com \
  --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Provisioning Eventarc & Pub/Sub Service Role Bindings...${RESET}"
SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/pubsub.publisher" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/eventarc.eventReceiver" --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating Cloud Storage Bucket in us-east4...${RESET}"
gsutil mb -l $REGION $BUCKET_URI 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Writing Source Code for Cloud Storage Function...${RESET}"
mkdir -p ~/storage_function && cd ~/storage_function

cat << EOF > index.js
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('$STORAGE_FUNCTION', (cloudevent) => {
  console.log('A new event in your Cloud Storage bucket has been logged!');
  console.log(cloudevent);
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Deploying Cloud Storage Function ($STORAGE_FUNCTION)...${RESET}"
echo -e "${YELLOW}Note: If Eventarc IAM permissions are still propagating, this step will auto-retry until successful.${RESET}"

MAX_RETRIES=4
RETRY_COUNT=0
DEPLOY_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy $STORAGE_FUNCTION \
    --gen2 \
    --runtime=nodejs24 \
    --entry-point=$STORAGE_FUNCTION \
    --source=. \
    --region=$REGION \
    --trigger-bucket=$BUCKET_NAME \
    --trigger-location=$REGION \
    --max-instances=2 \
    --quiet; then
    DEPLOY_SUCCESS=true
    break
  else
    echo -e "${RED}⚠️ Eventarc permissions propagating. Retrying in 30 seconds... ($((RETRY_COUNT+1))/$MAX_RETRIES)${RESET}"
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT+1))
  fi
done

if [ "$DEPLOY_SUCCESS" = false ]; then
  echo -e "${RED}❌ Deployment failed after $MAX_RETRIES attempts. Please check Cloud Shell for details.${RESET}"
  exit 1
fi

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Triggering the function to register activity...${RESET}"
echo "Triggering the function..." > test-event.txt
gsutil cp test-event.txt $BUCKET_URI/test-event.txt 2>/dev/null

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Writing Source Code for HTTP Function...${RESET}"
mkdir -p ~/http_function && cd ~/http_function

cat << EOF > index.js
const functions = require('@google-cloud/functions-framework');

functions.http('$HTTP_FUNCTION', (req, res) => {
  res.status(200).send('HTTP function (2nd gen) has been called!');
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Deploying HTTP Function ($HTTP_FUNCTION) with Scale Settings...${RESET}"
RETRY_COUNT=0
HTTP_DEPLOY_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy $HTTP_FUNCTION \
    --gen2 \
    --runtime=nodejs24 \
    --entry-point=$HTTP_FUNCTION \
    --source=. \
    --region=$REGION \
    --trigger-http \
    --allow-unauthenticated \
    --min-instances=1 \
    --max-instances=2 \
    --quiet; then
    HTTP_DEPLOY_SUCCESS=true
    break
  else
    echo -e "${RED}⚠️ API glitch detected. Retrying deployment in 30 seconds... ($((RETRY_COUNT+1))/$MAX_RETRIES)${RESET}"
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT+1))
  fi
done

if [ "$HTTP_DEPLOY_SUCCESS" = false ]; then
  echo -e "${RED}❌ HTTP Deployment failed after $MAX_RETRIES attempts. Please check Cloud Shell for details.${RESET}"
  exit 1
fi

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
