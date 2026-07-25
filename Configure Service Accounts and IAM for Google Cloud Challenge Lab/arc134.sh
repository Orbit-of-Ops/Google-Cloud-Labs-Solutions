#!/bin/bash

# ==============================================================================
# Orbit of Ops - Automated Cloud Lab Setup
# ==============================================================================

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'
ORANGE_TEXT=$'\033[38;5;208m'     
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Welcome message in Orbit of Ops branding
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}                 WELCOME TO ORBIT OF OPS${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}          Elevating your Cloud & DevOps Journey!${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}${BOLD_TEXT}🚀 Getting Lab Credentials & Initializing...${RESET_FORMAT}"

export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)
# Explicitly hardcoding zone as per lab instructions to prevent default zone mismatches
export ZONE="us-east1-c" 
export REGION="us-east1"

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# ------------------------------------------------------------------------------
# Phase 1: IAM & Compute Setup (Executed on lab-vm)
# ------------------------------------------------------------------------------
cat > prepare_disk.sh <<'EOF_END'

gcloud auth login --quiet

export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)
export ZONE="us-east1-c"

echo "--> Creating 'devops' service account..."
gcloud iam service-accounts create devops --display-name devops
sleep 15

SA=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=devops")

echo "--> Binding IAM roles to 'devops' account..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SA --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SA --role=roles/compute.instanceAdmin

echo "--> Creating 'vm-2' compute instance..."
gcloud compute instances create vm-2 \
--machine-type=e2-micro \
--service-account=$SA \
--zone=$ZONE \
--scopes=https://www.googleapis.com/auth/compute

echo "--> Defining custom 'My Company Admin' role..."
cat > role-definition.yaml <<EOF
title: "My Company Admin"
description: "My custom role description."
stage: "ALPHA"
includedPermissions:
- cloudsql.instances.connect
- cloudsql.instances.get
EOF

gcloud iam roles create editor --project $DEVSHELL_PROJECT_ID --file role-definition.yaml

echo "--> Creating 'bigquery-qwiklab' service account..."
gcloud iam service-accounts create bigquery-qwiklab --display-name bigquery-qwiklab
sleep 15

SA_BQ=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=bigquery-qwiklab")

echo "--> Binding IAM roles to 'bigquery-qwiklab' account..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member=serviceAccount:$SA_BQ --role=roles/bigquery.dataViewer
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member=serviceAccount:$SA_BQ --role=roles/bigquery.user

echo "--> Creating 'bigquery-instance' compute instance (using e2-micro to avoid resource exhaustion)..."
gcloud compute instances create bigquery-instance \
--machine-type=e2-micro \
--service-account=$SA_BQ \
--scopes=https://www.googleapis.com/auth/cloud-platform \
--zone=$ZONE

EOF_END

echo "${GREEN_TEXT}Executing Phase 1 script on lab-vm...${RESET_FORMAT}"
gcloud compute scp prepare_disk.sh lab-vm:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet
gcloud compute ssh lab-vm --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

sleep 30

# ------------------------------------------------------------------------------
# Phase 2: Python & BigQuery Setup (Executed on bigquery-instance)
# ------------------------------------------------------------------------------
echo
echo "${YELLOW_TEXT}${BOLD_TEXT}🚀 Preparing BigQuery environment on bigquery-instance...${RESET_FORMAT}"

cat > prepare_disk.sh <<'EOF_END'
echo "--> Installing Python dependencies..."
sudo apt-get update
sudo apt install python3 -y
sudo apt-get install -y git python3-pip python3.11-venv

python3 -m venv myvenv
source myvenv/bin/activate
pip install --upgrade pip
pip install google-cloud-bigquery pandas pyarrow db-dtypes google-auth

export PROJECT_ID=$(gcloud config get-value project)
export SA_EMAIL=$(gcloud config get-value account 2>/dev/null || curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" -H "Metadata-Flavor: Google")

echo "--> Authenticated as: $SA_EMAIL"
echo "--> Creating BigQuery Python script..."

# Matching the exact python code block requested by the lab instructions
cat > query.py <<EOF
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(
    service_account_email='$SA_EMAIL'
)

query = '''
SELECT name, SUM(number) as total_people
FROM \`bigquery-public-data.usa_names.usa_1910_2013\`
WHERE state = 'TX'
GROUP BY name, state
ORDER BY total_people DESC
LIMIT 20
'''

client = bigquery.Client(
    project='$PROJECT_ID',
    credentials=credentials
)

print(client.query(query).to_dataframe())
EOF

sleep 5

echo "--> Executing BigQuery script..."
source myvenv/bin/activate
python query.py
EOF_END

echo "${GREEN_TEXT}Executing Phase 2 script on bigquery-instance...${RESET_FORMAT}"
gcloud compute scp prepare_disk.sh bigquery-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet
gcloud compute ssh bigquery-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

# ------------------------------------------------------------------------------
# Completion Banner
# ------------------------------------------------------------------------------
echo
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo
echo "${BLUE_TEXT}${BOLD_TEXT}🚀 Keep exploring the Orbit of Ops!${RESET_FORMAT}"
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@orbitofops${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Please Subscribe to the channel for more Cloud & DevOps videos!${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe!${RESET_FORMAT}"
echo
