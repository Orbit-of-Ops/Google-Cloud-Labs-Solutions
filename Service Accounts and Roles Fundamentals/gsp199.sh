#!/usr/bin/env bash

# =========================================================
# ORBIT OF OPS 🚀 | GSP199 MASTER AUTOMATION SCRIPT
# =========================================================
# Lab: Service Accounts and Roles: Fundamentals
# Scope:
#   ➜ Create and bind IAM service accounts
#   ➜ Create Compute Engine VM with BigQuery service account
#   ➜ Install Python BigQuery libraries inside venv
#   ➜ Run BigQuery public dataset query automatically
#
# YouTube: https://www.youtube.com/@OrbitOfOps
# =========================================================

set -Eeuo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export DEBIAN_FRONTEND=noninteractive

# -------------------- COLORS --------------------
if [[ -t 1 ]]; then
  RED=$'\033[0;91m'
  GREEN=$'\033[0;92m'
  YELLOW=$'\033[0;93m'
  BLUE=$'\033[0;94m'
  CYAN=$'\033[0;96m'
  ORANGE=$'\033[38;5;208m'
  WHITE=$'\033[0;97m'
  BOLD=$'\033[1m'
  UNDERLINE=$'\033[4m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
  ORANGE=""
  WHITE=""
  BOLD=""
  UNDERLINE=""
  RESET=""
fi

# -------------------- BRANDING --------------------
orbit_banner() {
  clear || true
  echo
  echo "${CYAN}${BOLD}┌────────────────────────────────────────────────────────┐${RESET}"
  echo "${CYAN}${BOLD}│                                                        │${RESET}"
  echo "${CYAN}${BOLD}│        🌟 ORBIT OF OPS: GSP199 AUTOMATION 🌟           │${RESET}"
  echo "${CYAN}${BOLD}│                                                        │${RESET}"
  echo "${CYAN}${BOLD}└────────────────────────────────────────────────────────┘${RESET}"
  echo
  echo "${WHITE}${BOLD}📦 Delivery Scope:${RESET}"
  echo "${WHITE}   ➜ IAM Service Accounts${RESET}"
  echo "${WHITE}   ➜ Compute Engine Instance${RESET}"
  echo "${WHITE}   ➜ BigQuery Public Dataset Query${RESET}"
  echo
}

orbit_footer() {
  echo
  echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo "${ORANGE}${BOLD} 💫 Join the Mission: Subscribe to Orbit of Ops${RESET}"
  echo "${CYAN}${UNDERLINE} https://www.youtube.com/@OrbitOfOps${RESET}"
  echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
}

log_stage() {
  echo
  echo "${GREEN}${BOLD}=== $1 ===${RESET}"
  echo
}

log_info() {
  echo "${BLUE}${BOLD}➜ $1${RESET}"
}

log_success() {
  echo "${GREEN}${BOLD}✅ $1${RESET}"
}

log_warn() {
  echo "${YELLOW}${BOLD}⚠️  $1${RESET}"
}

log_error() {
  echo "${RED}${BOLD}❌ $1${RESET}"
}

fail() {
  log_error "$1"
  exit 1
}

trap 'log_error "Script failed near line $LINENO. Check the message above."' ERR

# -------------------- CONSTANTS --------------------
VM_NAME="bigquery-instance"
SA1_NAME="my-sa-123"
BQ_SA_NAME="bigquery-qwiklab"

orbit_banner
orbit_footer

# -------------------- PROJECT CHECK --------------------
log_stage "STAGE 1: PROJECT AND IDENTITY CHECK"

PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  fail "Project ID not found. Open Qwiklabs Cloud Shell after starting the lab."
fi

SA1_EMAIL="${SA1_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BQ_SA_EMAIL="${BQ_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

log_info "Project ID: $PROJECT_ID"
log_info "Checking active account..."
gcloud auth list

log_info "Enabling required APIs if allowed..."
gcloud services enable compute.googleapis.com iam.googleapis.com bigquery.googleapis.com --quiet >/dev/null 2>&1 || true

log_success "Environment check completed."

# -------------------- HELPER FUNCTIONS --------------------
clean_value() {
  local v="${1:-}"
  if [[ "$v" == "(unset)" || "$v" == "None" ]]; then
    echo ""
  else
    echo "$v"
  fi
}

region_from_zone() {
  echo "$1" | sed 's/-[a-z]$//'
}

ZONE_CANDIDATES=""

add_zone() {
  local z="${1:-}"
  if [[ -n "$z" ]]; then
    if ! echo "$ZONE_CANDIDATES" | tr ' ' '\n' | grep -qx "$z"; then
      ZONE_CANDIDATES="$ZONE_CANDIDATES $z"
    fi
  fi
}

add_region_zones() {
  local r="${1:-}"
  if [[ -n "$r" ]]; then
    add_zone "${r}-a"
    add_zone "${r}-b"
    add_zone "${r}-c"
  fi
}

find_existing_vm_zone() {
  gcloud compute instances list \
    --filter="name=(${VM_NAME})" \
    --format="value(zone)" 2>/dev/null | head -n 1 | awk -F/ '{print $NF}'
}

# -------------------- DYNAMIC ZONE RESOLUTION --------------------
log_stage "STAGE 2: DYNAMIC REGION AND ZONE RESOLUTION"

META_ZONE="$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null || true)"
META_REGION="$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null || true)"
CONFIG_ZONE="$(gcloud config get-value compute/zone 2>/dev/null || true)"
CONFIG_REGION="$(gcloud config get-value compute/region 2>/dev/null || true)"
EXISTING_VM_ZONE="$(find_existing_vm_zone || true)"

META_ZONE="$(clean_value "$META_ZONE")"
META_REGION="$(clean_value "$META_REGION")"
CONFIG_ZONE="$(clean_value "$CONFIG_ZONE")"
CONFIG_REGION="$(clean_value "$CONFIG_REGION")"
EXISTING_VM_ZONE="$(clean_value "$EXISTING_VM_ZONE")"

# Priority order
add_zone "$EXISTING_VM_ZONE"
add_zone "$META_ZONE"
add_zone "$CONFIG_ZONE"
add_region_zones "$META_REGION"
add_region_zones "$CONFIG_REGION"

# Official GSP199 fallback zones
add_zone "europe-west4-a"
add_zone "europe-west4-b"
add_zone "europe-west4-c"

log_info "Zone candidates:$ZONE_CANDIDATES"

if [[ -z "$ZONE_CANDIDATES" ]]; then
  fail "No zone candidates found."
fi

log_success "Zone resolution completed."

# -------------------- IAM SERVICE ACCOUNTS --------------------
log_stage "STAGE 3: IAM SERVICE ACCOUNT SETUP"

log_info "Creating service account: $SA1_NAME"

if gcloud iam service-accounts describe "$SA1_EMAIL" >/dev/null 2>&1; then
  log_warn "$SA1_NAME already exists. Skipping creation."
else
  gcloud iam service-accounts create "$SA1_NAME" \
    --display-name "my service account" \
    --quiet
fi

log_info "Binding Editor role to $SA1_NAME..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SA1_EMAIL}" \
  --role "roles/editor" \
  --quiet >/dev/null

log_info "Creating service account: $BQ_SA_NAME"

if gcloud iam service-accounts describe "$BQ_SA_EMAIL" >/dev/null 2>&1; then
  log_warn "$BQ_SA_NAME already exists. Skipping creation."
else
  gcloud iam service-accounts create "$BQ_SA_NAME" \
    --display-name "bigquery-qwiklab" \
    --quiet
fi

log_info "Binding BigQuery Data Viewer role..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${BQ_SA_EMAIL}" \
  --role "roles/bigquery.dataViewer" \
  --quiet >/dev/null

log_info "Binding BigQuery User role..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${BQ_SA_EMAIL}" \
  --role "roles/bigquery.user" \
  --quiet >/dev/null

log_info "Waiting for IAM propagation..."
sleep 15

log_success "IAM setup completed."
orbit_footer

# -------------------- VM CREATION OR REUSE --------------------
log_stage "STAGE 4: COMPUTE ENGINE INSTANCE BUILD"

VM_ZONE="$(find_existing_vm_zone || true)"
VM_ZONE="$(clean_value "$VM_ZONE")"

if [[ -n "$VM_ZONE" ]]; then
  REGION="$(region_from_zone "$VM_ZONE")"

  log_warn "VM $VM_NAME already exists in $VM_ZONE. Reusing it."

  gcloud config set compute/region "$REGION" --quiet >/dev/null
  gcloud config set compute/zone "$VM_ZONE" --quiet >/dev/null

  VM_STATUS="$(gcloud compute instances describe "$VM_NAME" \
    --zone "$VM_ZONE" \
    --format="value(status)" 2>/dev/null || true)"

  if [[ "$VM_STATUS" != "RUNNING" ]]; then
    log_info "Starting existing VM..."
    gcloud compute instances start "$VM_NAME" \
      --zone "$VM_ZONE" \
      --quiet
  fi

else
  VM_ZONE=""

  for TRY_ZONE in $ZONE_CANDIDATES; do
    TRY_REGION="$(region_from_zone "$TRY_ZONE")"

    echo
    log_info "Trying VM creation in zone: $TRY_ZONE"

    gcloud config set compute/region "$TRY_REGION" --quiet >/dev/null
    gcloud config set compute/zone "$TRY_ZONE" --quiet >/dev/null

    if gcloud compute instances create "$VM_NAME" \
      --project "$PROJECT_ID" \
      --zone "$TRY_ZONE" \
      --machine-type "e2-medium" \
      --image-family "debian-12" \
      --image-project "debian-cloud" \
      --service-account "$BQ_SA_EMAIL" \
      --scopes "https://www.googleapis.com/auth/bigquery" \
      --quiet; then

      VM_ZONE="$TRY_ZONE"
      log_success "VM created successfully in $VM_ZONE"
      break
    else
      log_warn "Zone $TRY_ZONE failed. Trying next candidate..."
    fi
  done

  if [[ -z "$VM_ZONE" ]]; then
    fail "VM could not be created in any candidate zone. Check lab region/zone."
  fi
fi

REGION="$(region_from_zone "$VM_ZONE")"
gcloud config set compute/region "$REGION" --quiet >/dev/null
gcloud config set compute/zone "$VM_ZONE" --quiet >/dev/null

log_success "Using VM zone: $VM_ZONE"
orbit_footer

# -------------------- SSH READINESS --------------------
log_stage "STAGE 5: SSH READINESS CHECK"

mkdir -p "$HOME/.ssh"
ssh-keygen -t rsa -f "$HOME/.ssh/google_compute_engine" -N "" -q <<< y >/dev/null 2>&1 || true

for i in {1..18}; do
  if gcloud compute ssh "$VM_NAME" \
    --zone "$VM_ZONE" \
    --project "$PROJECT_ID" \
    --quiet \
    --ssh-flag="-o StrictHostKeyChecking=no" \
    --command "echo SSH_READY" >/tmp/orbit_gsp199_ssh_check.log 2>&1; then

    log_success "SSH is ready."
    break
  fi

  log_warn "SSH not ready yet. Retry $i/18..."
  sleep 10

  if [[ "$i" == "18" ]]; then
    cat /tmp/orbit_gsp199_ssh_check.log || true
    fail "SSH did not become ready."
  fi
done

# -------------------- REMOTE WORKLOAD --------------------
log_stage "STAGE 6: REMOTE BIGQUERY WORKLOAD COMPILATION"

cat > orbit_gsp199_remote_task.sh <<REMOTE_EOF
#!/usr/bin/env bash

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

cd "\$HOME"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 🚀 Orbit of Ops Remote Runtime Started"
echo " 👉 https://www.youtube.com/@OrbitOfOps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "Updating package lists..."
sudo apt-get update -y

echo "Installing Python, pip, venv, and git..."
sudo apt-get install -y python3 python3-pip python3.11-venv python3-full git

echo "Creating clean Python virtual environment..."
rm -rf "\$HOME/myvenv"
python3 -m venv "\$HOME/myvenv"

echo "Upgrading pip inside virtual environment..."
"\$HOME/myvenv/bin/python" -m pip install --upgrade pip

echo "Installing BigQuery libraries inside virtual environment..."
"\$HOME/myvenv/bin/python" -m pip install --no-cache-dir google-cloud-bigquery pyarrow pandas db-dtypes

echo "Creating query.py..."

cat > "\$HOME/query.py" <<PY_EOF
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(
    service_account_email="${BQ_SA_EMAIL}"
)

query = '''
SELECT
  year,
  COUNT(1) as num_babies
FROM
  publicdata.samples.natality
WHERE
  year > 2000
GROUP BY
  year
'''

client = bigquery.Client(
    project="${PROJECT_ID}",
    credentials=credentials
)

print(client.query(query).to_dataframe())
PY_EOF

echo
echo "Running BigQuery query..."
"\$HOME/myvenv/bin/python" "\$HOME/query.py"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Orbit of Ops Remote Runtime Completed"
echo " 👉 https://www.youtube.com/@OrbitOfOps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

REMOTE_EOF

log_info "Copying remote script to VM..."

gcloud compute scp orbit_gsp199_remote_task.sh "$VM_NAME:/tmp/orbit_gsp199_remote_task.sh" \
  --zone "$VM_ZONE" \
  --project "$PROJECT_ID" \
  --quiet

log_info "Executing remote script on VM..."

gcloud compute ssh "$VM_NAME" \
  --zone "$VM_ZONE" \
  --project "$PROJECT_ID" \
  --quiet \
  --ssh-flag="-o StrictHostKeyChecking=no" \
  --command "chmod +x /tmp/orbit_gsp199_remote_task.sh && /tmp/orbit_gsp199_remote_task.sh"

# -------------------- FINAL --------------------
log_stage "MISSION STATUS"

log_success "GSP199 automation completed successfully."
log_success "Now click both Check my progress buttons in Qwiklabs."

rm -f orbit_gsp199_remote_task.sh

echo
echo "${GREEN}${BOLD}┌────────────────────────────────────────────────────────┐${RESET}"
echo "${GREEN}${BOLD}│        MISSION ACCOMPLISHED: GSP199 COMPLETED          │${RESET}"
echo "${GREEN}${BOLD}└────────────────────────────────────────────────────────┘${RESET}"

orbit_footer

