#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP080 MASTER SCRIPT
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo "${RESET}"
echo "${MAGENTA}${BOLD}>>> INITIATING GSP080: CLOUD RUN FUNCTIONS (PUB/SUB) SCRIPT <<<${RESET}"
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
if [ -z "$REGION" ]; then export REGION="us-central1"; fi

echo "${YELLOW}[*] Phase 1: Syncing Backend APIs (Qwiklabs Fix)...${RESET}"
# Toggling the API forces an IAM sync on the backend to prevent deployment errors
gcloud services disable cloudfunctions.googleapis.com --quiet 2>/dev/null || true
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com pubsub.googleapis.com eventarc.googleapis.com --quiet
sleep 15

echo -e "\n${CYAN}[*] Phase 2: Generating Function Source Code...${RESET}"
mkdir -p gcf_hello_world && cd gcf_hello_world

cat << 'EOF' > package.json
{
  "name": "gcf_hello_world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

// Register a CloudEvent callback with the Functions Framework that will
// be executed when the Pub/Sub trigger topic receives a message.
functions.cloudEvent('helloPubSub', cloudEvent => {
  // The Pub/Sub message is passed as the CloudEvent's data payload.
  const base64name = cloudEvent.data.message.data;

  const name = base64name
    ? Buffer.from(base64name, 'base64').toString()
    : 'World';

  console.log(`Hello, ${name}!`);
});
EOF

echo -e "\n${YELLOW}[*] Phase 3: Installing npm dependencies...${RESET}"
npm install

echo -e "\n${MAGENTA}[*] Phase 4: Deploying Cloud Run Function (nodejs-pubsub-function)...${RESET}"
echo "${WHITE}This typically takes 2-3 minutes. If it fails due to Qwiklabs API delays, the script will automatically retry.${RESET}"

MAX_RETRIES=3
RETRY_COUNT=0
DEPLOY_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy nodejs-pubsub-function \
    --gen2 \
    --runtime=nodejs20 \
    --region=$REGION \
    --source=. \
    --entry-point=helloPubSub \
    --trigger-topic cf-demo \
    --stage-bucket $PROJECT_ID-bucket \
    --service-account cloudfunctionsa@$PROJECT_ID.iam.gserviceaccount.com \
    --allow-unauthenticated \
    --quiet; then
    DEPLOY_SUCCESS=true
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo -e "\n${YELLOW}Backend API propagation delayed. Retrying deployment ($RETRY_COUNT/$MAX_RETRIES) in 30 seconds...${RESET}"
    sleep 30
  fi
done

if [ "$DEPLOY_SUCCESS" = true ]; then
  echo -e "\n${GREEN}${BOLD}[+] Function deployed successfully!${RESET}"
  echo -e "\n${GREEN}${BOLD}====================================================================${RESET}"
  echo "${GREEN}${BOLD}>>> LAB 100% COMPLETE! YOU CAN NOW CLICK 'CHECK MY PROGRESS' <<<${RESET}"
  echo "${GREEN}${BOLD}====================================================================${RESET}"
else
  echo -e "\n${RED}${BOLD}Function deployment failed after multiple retries. Please check the Cloud Console for specific error logs.${RESET}"
fi
