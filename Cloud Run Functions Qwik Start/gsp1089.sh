#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP1089 COMPLETE MASTER SCRIPT
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
echo "${MAGENTA}${BOLD}>>> INITIATING GSP1089 COMPLETE AUTOMATION PIPELINE <<<${RESET}"
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$REGION" ]; then export REGION="us-central1"; fi
if [ -z "$ZONE" ]; then export ZONE="us-central1-a"; fi

gcloud config set compute/region $REGION --quiet

# ==============================================================================
# PHASE 1: API ACTIVATION & ADVANCED IAM SETUP
# ==============================================================================
echo "${YELLOW}[*] Phase 1: Activating Google Cloud Service APIs...${RESET}"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com \
  cloudaicompanion.googleapis.com \
  --quiet

echo -e "\n${YELLOW}[*] Phase 2: Provisioning Pub/Sub & Eventarc Service Role Bindings...${RESET}"
SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/pubsub.publisher" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" --role="roles/eventarc.eventReceiver" --quiet

echo -e "\n${YELLOW}[*] Phase 3: Writing Project IAM Audit Logging Configurations...${RESET}"
gcloud projects get-iam-policy $PROJECT_ID > policy.yaml
cat <<EOF >> policy.yaml
auditConfigs:
- auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
  service: compute.googleapis.com
EOF
gcloud projects set-iam-policy $PROJECT_ID policy.yaml --quiet
rm -f policy.yaml

echo -e "\n${MAGENTA}${BOLD}[!] Waiting 90 seconds for Eventarc IAM permissions to propagate on the GCP Backend...${RESET}"
sleep 90

# ==============================================================================
# PHASE 2: TASK 2 - HTTP FUNCTION DEPLOYMENT
# ==============================================================================
echo -e "\n${CYAN}[*] Phase 4: Deploying Authenticated HTTP Function (Task 2)...${RESET}"
mkdir -p ~/hello-http && cd ~/hello-http

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');
functions.http('helloWorld', (req, res) => {
  res.status(200).send('HTTP with Node.js in GCF 2nd gen!');
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

gcloud functions deploy nodejs-http-function \
  --gen2 \
  --runtime=nodejs22 \
  --entry-point=helloWorld \
  --source=. \
  --region=$REGION \
  --trigger-http \
  --timeout=600s \
  --max-instances=1 \
  --allow-unauthenticated \
  --quiet

# ==============================================================================
# PHASE 3: TASK 3 - CLOUD STORAGE TRIGGER FUNCTION
# ==============================================================================
echo -e "\n${BLUE}[*] Phase 5: Provisioning Storage Bucket & Storage Function (Task 3)...${RESET}"
mkdir -p ~/hello-storage && cd ~/hello-storage

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');
functions.cloudEvent('helloStorage', (cloudevent) => {
  console.log('Cloud Storage event with Node.js in GCF 2nd gen!');
  console.log(cloudevent);
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

export BUCKET="gs://gcf-gen2-storage-$PROJECT_ID"
gsutil mb -l $REGION $BUCKET 2>/dev/null || true

MAX_RETRIES=3
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy nodejs-storage-function \
    --gen2 \
    --runtime=nodejs22 \
    --entry-point=helloStorage \
    --source=. \
    --region=$REGION \
    --trigger-bucket=$BUCKET \
    --trigger-location=$REGION \
    --max-instances=1 \
    --quiet; then
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo -e "\n${YELLOW}Eventarc API glitch detected. Retrying deployment in 30 seconds...${RESET}"
    sleep 30
  fi
done

echo "Hello World" > random.txt
gsutil cp random.txt $BUCKET/random.txt 2>/dev/null

# ==============================================================================
# PHASE 4: TASK 4 - CLOUD AUDIT LOGS FUNCTION
# ==============================================================================
echo -e "\n${MAGENTA}[*] Phase 6: Cloning Samples & Deploying Audit Logs VM Labeler (Task 4)...${RESET}"
cd ~
git clone https://github.com/GoogleCloudPlatform/eventarc-samples.git 2>/dev/null || true
cd ~/eventarc-samples/gce-vm-labeler/gcf/nodejs

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy gce-vm-labeler \
    --gen2 \
    --runtime=nodejs22 \
    --entry-point=labelVmCreation \
    --source=. \
    --region=$REGION \
    --trigger-event-filters="type=google.cloud.audit.log.v1.written,serviceName=compute.googleapis.com,methodName=beta.compute.instances.insert" \
    --trigger-location=$REGION \
    --max-instances=1 \
    --quiet; then
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo -e "\n${YELLOW}Eventarc API glitch detected. Retrying deployment in 30 seconds...${RESET}"
    sleep 30
  fi
done

gcloud compute instances create instance-1 --zone=$ZONE --machine-type=e2-micro --quiet

# ==============================================================================
# PHASE 5: TASK 5 - DEPLOY REVISIONS & TRAFFIC SPLITTING
# ==============================================================================
echo -e "\n${CYAN}[*] Phase 7: Testing Python Environmental Revisions (Task 5)...${RESET}"
mkdir -p ~/hello-world-colored && cd ~/hello-world-colored
touch requirements.txt

cat << 'EOF' > main.py
import os
color = os.environ.get('COLOR')
def hello_world(request):
    return f'<body style="background-color:{color}"><h1>Hello World!</h1></body>'
EOF

gcloud functions deploy hello-world-colored \
  --gen2 \
  --runtime=python311 \
  --entry-point=hello_world \
  --source=. \
  --region=$REGION \
  --trigger-http \
  --allow-unauthenticated \
  --update-env-vars=COLOR=orange \
  --max-instances=1 \
  --quiet

gcloud functions deploy hello-world-colored \
  --gen2 \
  --region=$REGION \
  --update-env-vars=COLOR=yellow \
  --quiet

# ==============================================================================
# PHASE 6: TASK 6 & 7 - SCALING MIN INSTANCES & CONCURRENCY
# ==============================================================================
echo -e "\n${YELLOW}[*] Phase 8: Deploying Scaled Go Application Service (Task 6)...${RESET}"
mkdir -p ~/min-instances && cd ~/min-instances

cat << 'EOF' > main.go
package p
import (
        "fmt"
        "net/http"
        "time"
)
func init() {
        time.Sleep(10 * time.Second)
}
func HelloWorld(w http.ResponseWriter, r *http.Request) {
        fmt.Fprint(w, "Slow HTTP Go in GCF 2nd gen!")
}
EOF

cat << 'EOF' > go.mod
module example.com/mod
go 1.23
EOF

gcloud functions deploy slow-function \
  --gen2 \
  --runtime=go123 \
  --entry-point=HelloWorld \
  --source=. \
  --region=$REGION \
  --trigger-http \
  --allow-unauthenticated \
  --max-instances=4 \
  --quiet

echo -e "\n${YELLOW}[*] Phase 9: Eliminating Cold Starts via Minimum Instance Scale Up...${RESET}"
gcloud run services update slow-function --min-instances=1 --max-instances=4 --region=$REGION --quiet

echo -e "\n${MAGENTA}[*] Phase 10: Upgrading to Concurrency Architecture (Task 7)...${RESET}"
gcloud functions deploy slow-concurrent-function \
  --gen2 \
  --runtime=go123 \
  --entry-point=HelloWorld \
  --source=. \
  --region=$REGION \
  --trigger-http \
  --allow-unauthenticated \
  --min-instances=1 \
  --max-instances=4 \
  --quiet

echo -e "\n${GREEN}[*] Phase 11: Applying Concurrency & Dedicated Compute Patches...${RESET}"
gcloud run services update slow-concurrent-function \
  --concurrency=100 \
  --cpu=1 \
  --memory=1024Mi \
  --max-instances=4 \
  --region=$REGION \
  --quiet

echo -e "\n${GREEN}${BOLD}====================================================================${RESET}"
echo "${GREEN}${BOLD}>>> PIPELINE COMPLETE! ALL TASKS ARE PROVISIONED AND GRADED <<<${RESET}"
echo "${GREEN}${BOLD}====================================================================${RESET}"
