cat > gsp514.sh <<'EOF_SCRIPT'
#!/bin/bash
clear

RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
MAGENTA='\e[0;35m'
CYAN='\e[0;36m'
WHITE='\e[0;37m'
BOLD='\e[1m'
RESET='\e[0m'
BG_GREEN='\e[42m'
BG_MAGENTA='\e[45m'

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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops (GSP514: Data Mesh Challenge Lab) ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo -e "${YELLOW}${BOLD}[*] Auto-Fetching Lab Region from pre-created resources...${RESET}"
export REGION=$(gcloud storage buckets describe gs://$PROJECT_ID-customer-online-sessions --format="value(location)" 2>/dev/null | tr '[:upper:]' '[:lower:]')
if [ -z "$REGION" ]; then
    export REGION=$(bq show --format=json ${PROJECT_ID}:customer_orders 2>/dev/null | grep -o '"location": "[^"]*' | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]')
fi
echo -e "${GREEN}${BOLD}[*] Region successfully identified: ${REGION}${RESET}\n"

echo -e "${BOLD}${MAGENTA}⚠️  ATTENTION: USER 2 CREDENTIALS REQUIRED ⚠️${RESET}"
read -p "Enter User 2 Email (e.g., student-xx-xxxx@qwiklabs.net): " USER2_EMAIL
echo "--------------------------------------------------------------------------------"

echo -e "${BOLD}${BLUE}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com dataproc.googleapis.com --quiet

echo ""
echo -e "${BOLD}${BLUE}[Orbit of Ops] Task 1: Building Infrastructure...${RESET}"
gcloud dataplex lakes create sales-lake --location=$REGION --display-name="Sales Lake" --quiet 2>/dev/null || true
gcloud dataplex zones create raw-customer-zone --lake=sales-lake --location=$REGION --resource-location-type=SINGLE_REGION --display-name="Raw Customer Zone" --discovery-enabled --type=RAW --quiet 2>/dev/null || true
gcloud dataplex zones create curated-customer-zone --lake=sales-lake --location=$REGION --resource-location-type=SINGLE_REGION --display-name="Curated Customer Zone" --discovery-enabled --type=CURATED --quiet 2>/dev/null || true
gcloud dataplex assets create customer-engagements --lake=sales-lake --zone=raw-customer-zone --location=$REGION --display-name="Customer Engagements" --resource-type=STORAGE_BUCKET --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID-customer-online-sessions --discovery-enabled --quiet 2>/dev/null || true
gcloud dataplex assets create customer-orders --lake=sales-lake --zone=curated-customer-zone --location=$REGION --display-name="Customer Orders" --resource-type=BIGQUERY_DATASET --resource-name=projects/$PROJECT_ID/datasets/customer_orders --discovery-enabled --quiet 2>/dev/null || true

echo ""
echo -e "${BOLD}${MAGENTA}[Orbit of Ops] Task 2: Creating 'Protected Customer Data' Aspect Type...${RESET}"
cat > aspect_template.json <<EOF
{
  "name": "protected_customer_data_template",
  "type": "record",
  "recordFields": [
    {
      "name": "raw_data_flag",
      "type": "enum",
      "index": 1,
      "annotations": { "displayName": "Raw Data Flag" },
      "constraints": { "required": true },
      "enumValues": [ { "name": "Yes", "index": 1 }, { "name": "No", "index": 2 } ]
    },
    {
      "name": "protected_contact_information_flag",
      "type": "enum",
      "index": 2,
      "annotations": { "displayName": "Protected Contact Information Flag" },
      "constraints": { "required": true },
      "enumValues": [ { "name": "Yes", "index": 1 }, { "name": "No", "index": 2 } ]
    }
  ]
}
EOF
gcloud dataplex aspect-types create protected-customer-data-aspect --location=$REGION --display-name="Protected Customer Data Aspect" --metadata-template-file-name=aspect_template.json --quiet 2>/dev/null || true

echo ""
echo -e "${BOLD}${MAGENTA}[Orbit of Ops] Task 3: Granting 'Dataplex Data Writer' role to User 2...${RESET}"
gcloud dataplex assets add-iam-policy-binding customer-engagements --location=$REGION --lake=sales-lake --zone=raw-customer-zone --role=roles/dataplex.dataWriter --member=user:$USER2_EMAIL --quiet 2>/dev/null || true

echo ""
echo -e "${BOLD}${BLUE}[Orbit of Ops] Task 4: Creating 'orders_dq_dataset' for results...${RESET}"
bq mk --location=$REGION ${PROJECT_ID}:orders_dq_dataset 2>/dev/null || true

echo ""
echo -e "${BOLD}${BLUE}[Orbit of Ops] Task 4: Generating & Uploading Auto Data Quality YAML...${RESET}"
cat > dq-customer-orders.yaml <<EOF
rules:
- column: user_id
  dimension: COMPLETENESS
  nonNullExpectation: {}
  threshold: 1.0
- column: order_id
  dimension: COMPLETENESS
  nonNullExpectation: {}
  threshold: 1.0
postScanActions:
  bigqueryExport:
    resultsTable: projects/$PROJECT_ID/datasets/orders_dq_dataset/tables/results
EOF
gcloud storage cp dq-customer-orders.yaml gs://$PROJECT_ID-dq-config/

echo ""
echo -e "${BOLD}${GREEN}[Orbit of Ops] Task 5: Launching Auto Data Quality scan via CLI...${RESET}"
gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
  --project=$PROJECT_ID \
  --location=$REGION \
  --data-source-resource="//bigquery.googleapis.com/projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
  --data-quality-spec-file="gs://$PROJECT_ID-dq-config/dq-customer-orders.yaml" \
  --quiet

gcloud dataplex datascans run customer-orders-data-quality-job --project=$PROJECT_ID --location=$REGION --quiet

rm aspect_template.json dq-customer-orders.yaml 2>/dev/null

echo ""
echo "--------------------------------------------------------------------------------"
echo -e "${BG_GREEN}${WHITE}${BOLD} 🎉 AUTOMATION COMPLETE! Tasks 1, 3, 4, AND 5 are running/done! ${RESET}"
echo "--------------------------------------------------------------------------------"
echo -e "${BG_MAGENTA}${WHITE}${BOLD} ⚠️  ONLY ONE UI STEP LEFT (FINISH TASK 2) ⚠️  ${RESET}"
echo ""
echo -e "${CYAN}${BOLD}1. Go to: ${WHITE}Navigation Menu > Knowledge Catalog > Search${RESET}"
echo -e "${CYAN}${BOLD}2. Type 'Raw Customer Zone' into the search bar and click it.${RESET}"
echo -e "${CYAN}${BOLD}3. Scroll down to 'Optional aspects' and click 'Add'.${RESET}"
echo -e "${CYAN}${BOLD}4. Select 'Protected Customer Data Aspect'. Set BOTH flags to 'Yes', then click Save.${RESET}"
echo ""
echo -e "${YELLOW}${BOLD}Once you save that aspect, wait exactly 3 minutes for the automated Data Scan (Task 5) to finish in the background, then click 'Check my progress' on ALL tasks!${RESET}"
echo "--------------------------------------------------------------------------------"
EOF_SCRIPT

sudo chmod +x gsp514.sh
./gsp514.sh
