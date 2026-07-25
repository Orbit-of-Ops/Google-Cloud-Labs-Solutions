#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS - COLOR PALETTE & BRANDING (PASTE-SAFE)
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)
BG_MAGENTA=$(tput setab 5)
BG_BLUE=$(tput setab 4)

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
echo "${MAGENTA}${BOLD}>>> COMMAND CENTER: GSP766 (GKE COST OPTIMIZATION) <<<${RESET}"
echo ""

# ==============================================================================
# AUTHENTICATION LOCK
# ==============================================================================
echo "${BOLD}${YELLOW}[*] Verifying Cloud Shell Authentication...${RESET}"
gcloud auth list
echo "${CYAN}(If a popup appeared asking to Authorize, please click it now.)${RESET}"
sleep 3
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
# Extract the exact zone where the cluster was provisioned
export ZONE=$(gcloud container clusters list --filter="name=multi-tenant-cluster" --format="value(location)" 2>/dev/null)

if [ -z "$ZONE" ]; then
    echo "${BOLD}${RED}[!] Cluster not found. Did you wait 5 minutes for the lab to finish provisioning?${RESET}"
    exit 1
fi

echo "${BOLD}${BLUE}[*] Project ID:${RESET} $PROJECT_ID"
echo "${BOLD}${BLUE}[*] Cluster Zone:${RESET} $ZONE"
echo ""

# ==============================================================================
# TASK 1: DOWNLOAD FILES & AUTHENTICATE CLUSTER
# ==============================================================================
echo "${BOLD}${MAGENTA}[*] Task 1: Downloading Configurations & Syncing Cluster...${RESET}"
cd ~
gsutil -m cp -r gs://spls/gsp766/gke-qwiklab ~ >/dev/null 2>&1
cd ~/gke-qwiklab

gcloud config set compute/zone ${ZONE} --quiet
gcloud container clusters get-credentials multi-tenant-cluster --zone ${ZONE} --quiet

# ==============================================================================
# TASK 2: VIEW AND CREATE NAMESPACES
# ==============================================================================
echo "${BOLD}${CYAN}[*] Task 2: Provisioning Namespaces (team-a & team-b)...${RESET}"
kubectl create namespace team-a 2>/dev/null || true
kubectl create namespace team-b 2>/dev/null || true

echo "${BOLD}${YELLOW}[*] Deploying Pods to Namespaces...${RESET}"
# Note: Using quay.io/centos/centos:9 to align with specific grader requirements
kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity
kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-b -- sleep infinity

kubectl config set-context --current --namespace=team-a

# ==============================================================================
# TASK 3: ACCESS CONTROL IN NAMESPACES (RBAC)
# ==============================================================================
echo "${BOLD}${BLUE}[*] Task 3: Configuring IAM and RBAC Permissions...${RESET}"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/container.clusterViewer --quiet >/dev/null

kubectl create role pod-reader \
    --resource=pods --verb=watch --verb=get --verb=list 2>/dev/null || true

kubectl create -f developer-role.yaml 2>/dev/null || true

kubectl create rolebinding team-a-developers \
    --role=developer --user=team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com 2>/dev/null || true

gcloud iam service-accounts keys create /tmp/key.json \
    --iam-account team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com --quiet >/dev/null

# ==============================================================================
# TASK 4: RESOURCE QUOTAS
# ==============================================================================
echo "${BOLD}${MAGENTA}[*] Task 4: Enforcing Kubernetes Resource Quotas...${RESET}"
kubectl create quota test-quota \
    --hard=count/pods=2,count/services.loadbalancers=1 --namespace=team-a 2>/dev/null || true

kubectl run app-server-2 --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity

echo "${CYAN}(Deliberately failing pod creation to test quota limits...)${RESET}"
kubectl run app-server-3 --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity 2>/dev/null || true
sleep 5

echo "${BOLD}${YELLOW}[*] Expanding Quota Limits & Enforcing CPU/Memory Policies...${RESET}"
kubectl get quota test-quota --namespace=team-a -o yaml | sed 's/count\/pods: "2"/count\/pods: "6"/' | kubectl apply -f -

kubectl create -f cpu-mem-quota.yaml 2>/dev/null || true
kubectl create -f cpu-mem-demo-pod.yaml --namespace=team-a 2>/dev/null || true

# ==============================================================================
# TASK 5: GKE USAGE METERING & BIGQUERY EXPORT
# ==============================================================================
echo "${BOLD}${CYAN}[*] Task 5: Injecting Usage Metering into GKE (Takes ~2-3 minutes)...${RESET}"
gcloud container clusters update multi-tenant-cluster \
    --zone ${ZONE} \
    --resource-usage-bigquery-dataset cluster_dataset --quiet

echo "${BOLD}${BLUE}[*] Rendering BigQuery Cost Breakdown Template...${RESET}"
export GCP_BILLING_EXPORT_TABLE_FULL_PATH=${PROJECT_ID}.billing_dataset.gcp_billing_export_v1_xxxx
export USAGE_METERING_DATASET_ID=cluster_dataset
export COST_BREAKDOWN_TABLE_ID=usage_metering_cost_breakdown
export USAGE_METERING_QUERY_TEMPLATE=~/gke-qwiklab/usage_metering_query_template.sql
export USAGE_METERING_QUERY=cost_breakdown_query.sql
export USAGE_METERING_START_DATE=2020-10-26

sed \
-e "s/\${fullGCPBillingExportTableID}/$GCP_BILLING_EXPORT_TABLE_FULL_PATH/" \
-e "s/\${projectID}/$PROJECT_ID/" \
-e "s/\${datasetID}/$USAGE_METERING_DATASET_ID/" \
-e "s/\${startDate}/$USAGE_METERING_START_DATE/" \
"$USAGE_METERING_QUERY_TEMPLATE" \
> "$USAGE_METERING_QUERY"

echo ""
echo "${BG_MAGENTA}${WHITE}${BOLD}====================================================================${RESET}"
echo "${BG_MAGENTA}${WHITE}${BOLD} ⚠️ CRITICAL MANUAL AUTHENTICATION STEP ⚠️                          ${RESET}"
echo "${BG_MAGENTA}${WHITE}${BOLD}====================================================================${RESET}"
echo "${BOLD}${YELLOW}The next command will pause and output a URL starting with 'https://'${RESET}"
echo "${BOLD}${WHITE}1. Click the URL and open it in a new tab.${RESET}"
echo "${BOLD}${WHITE}2. Sign in with your provided QWIKLABS STUDENT ACCOUNT.${RESET}"
echo "${BOLD}${WHITE}3. Click 'Allow' to authorize the BigQuery Data Transfer.${RESET}"
echo "${BOLD}${WHITE}4. Copy the authorization code provided.${RESET}"
echo "${BOLD}${WHITE}5. Paste the code into this terminal and hit ENTER.${RESET}"
echo ""

bq query \
--project_id=$PROJECT_ID \
--use_legacy_sql=false \
--destination_table=$USAGE_METERING_DATASET_ID.$COST_BREAKDOWN_TABLE_ID \
--schedule='every 24 hours' \
--display_name="GKE Usage Metering Cost Breakdown Scheduled Query" \
--replace=true \
"$(cat $USAGE_METERING_QUERY)"

echo ""
echo "${BG_BLUE}${WHITE}${BOLD}                                                                            ${RESET}"
echo "${BG_BLUE}${WHITE}${BOLD}  🚀 ORBIT OF OPS: ARCHITECTURE COMPLETE. FINAL UI STEPS REQUIRED.          ${RESET}"
echo "${BG_BLUE}${WHITE}${BOLD}                                                                            ${RESET}"
echo ""
echo "${BOLD}${GREEN}You can now click 'Check my progress' for Tasks 1, 2, 3, & 4!${RESET}"
echo ""
echo "${BOLD}${CYAN}--- TASK 5: FINAL UI STEP (Looker/Data Studio) ---${RESET}"
echo "1. Go to ${BOLD}Looker Studio (Data Studio)${RESET} in a new tab: https://datastudio.google.com/"
echo "2. Click ${BOLD}Create > Data Source${RESET}."
echo "3. Complete the account setup (Select your Country, put 'Qwiklabs' for Company, skip emails)."
echo "4. Select the ${BOLD}BigQuery${RESET} connector and click ${BOLD}Authorize${RESET}."
echo "5. Rename the source at the top left to: ${BOLD}GKE Usage${RESET}"
echo "6. Select ${BOLD}CUSTOM QUERY${RESET} in the first column, and pick your Project ID."
echo "7. Paste this EXACT query:"
echo "${GREEN}SELECT * FROM \`${PROJECT_ID}.cluster_dataset.usage_metering_cost_breakdown\`${RESET}"
echo "8. Click the blue ${BOLD}CONNECT${RESET} button in the top right."
echo "   ${YELLOW}* Click 'Check My Progress' for Task 5! *${RESET}"
echo ""
