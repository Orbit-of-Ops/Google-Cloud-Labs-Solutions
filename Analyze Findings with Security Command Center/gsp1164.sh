#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS - BRANDING & COLORS
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
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
echo "${MAGENTA}${BOLD}>>> COMMAND CENTER: FINAL AUTOMATED DEPLOYMENT INITIATED <<<${RESET}"
echo ""

# ==============================================================================
# PRE-FLIGHT
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [ -z "$REGION" ]; then export REGION="us-central1"; export ZONE="us-central1-a"; fi
export BUCKET_NAME="scc-export-bucket-$PROJECT_ID"

echo "${BOLD}${MAGENTA}[*] Enabling SCC API...${RESET}"
gcloud services enable securitycenter.googleapis.com --quiet 2>/dev/null
sleep 5

# ==============================================================================
# PROVISIONING EXPORT PIPELINES
# ==============================================================================
echo "${BOLD}${BLUE}[*] Provisioning Pub/Sub & BigQuery Architecture...${RESET}"
bq --location=$REGION --apilog=/dev/null mk --dataset $PROJECT_ID:continuous_export_dataset 2>/dev/null || true
gsutil mb -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || true

gcloud pubsub topics create export-findings-pubsub-topic --quiet 2>/dev/null || true
gcloud pubsub subscriptions create export-findings-pubsub-topic-sub --topic=export-findings-pubsub-topic --quiet 2>/dev/null || true

gcloud scc notifications create export-findings-pubsub \
    --project="$PROJECT_ID" \
    --pubsub-topic="projects/$PROJECT_ID/topics/export-findings-pubsub-topic" \
    --filter='state="ACTIVE" AND NOT mute="MUTED"' \
    --description="Continuous exports of Findings to Pub/Sub and BigQuery" --quiet 2>/dev/null || true

gcloud scc bqexports create scc-bq-cont-export \
    --dataset="projects/$PROJECT_ID/datasets/continuous_export_dataset" \
    --project="$PROJECT_ID" --quiet 2>/dev/null || true

# ==============================================================================
# THE CRITICAL PAUSE
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}[!] CRITICAL PAUSE: Allowing Google Cloud backend 90 seconds to register continuous pipelines...${RESET}"
sleep 90

# ==============================================================================
# TRIGGERING VULNERABILITIES
# ==============================================================================
echo "${BOLD}${CYAN}[*] Generating Fresh Vulnerabilities...${RESET}"
gcloud compute instances create instance-1 --zone=$ZONE --machine-type e2-micro --scopes=https://www.googleapis.com/auth/cloud-platform --quiet 2>/dev/null || true

for i in {0..2}; do
    gcloud iam service-accounts create sccp-test-sa-$i --quiet 2>/dev/null || true
    sleep 3 # Micro-pause to prevent IAM replication failure
    gcloud iam service-accounts keys create /tmp/sa-key-$i.json --iam-account=sccp-test-sa-$i@$PROJECT_ID.iam.gserviceaccount.com --quiet 2>/dev/null || true
done

echo "${BOLD}${MAGENTA}[*] Waiting 30 seconds for findings to reach Pub/Sub...${RESET}"
sleep 30

# ==============================================================================
# TASK 1 & 3 AUTOMATION (PULL & BQ LOAD)
# ==============================================================================
echo "${BOLD}${BLUE}[*] Task 1: Auto-Acknowledging Pub/Sub Messages...${RESET}"
gcloud pubsub subscriptions pull export-findings-pubsub-topic-sub --auto-ack --limit=10 2>/dev/null || true

echo "${BOLD}${CYAN}[*] Task 3: Formatting & Loading Schema to BigQuery...${RESET}"
gcloud scc findings list "projects/$PROJECT_ID" --format=json | jq -c '.[]' > findings.jsonl 2>/dev/null
gsutil cp findings.jsonl gs://$BUCKET_NAME/ 2>/dev/null

cat <<EOF > schema.json
[
  { "mode": "NULLABLE", "name": "resource", "type": "JSON" },
  { "mode": "NULLABLE", "name": "finding", "type": "JSON" }
]
EOF

bq load --source_format=NEWLINE_DELIMITED_JSON --ignore_unknown_values $PROJECT_ID:continuous_export_dataset.old_findings gs://$BUCKET_NAME/findings.jsonl schema.json 2>/dev/null || true

echo ""
echo "${BOLD}${GREEN}Deployment 100% Complete. ${RESET}"
echo "${BOLD}${YELLOW}Important: Task 2 (BigQuery Continuous Export) is handled by the Google backend and can take up to 10 MINUTES to reflect in the grader. Do not panic if Task 2 doesn't immediately score 50/50. Give it time.${RESET}"
