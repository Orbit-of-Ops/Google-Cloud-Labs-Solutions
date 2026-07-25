#!/usr/bin/env bash
# GSP647 safer script 02 - run INSIDE centos-clean VM SSH
# It does not depend on /tmp/orbit_gsp647_vars.env.
# It asks all required values again and resumes safely if some tasks are already done.

set -Euo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export DEBIAN_FRONTEND=noninteractive

trap 'code=$?; echo; echo "❌ Error on line $LINENO. Exit code: $code"; echo "Last command: $BASH_COMMAND"; echo "You can re-run this same script after fixing the shown issue."; exit $code' ERR

LAB1_NAME="lab-1"
LAB2_NAME="lab-2"
LAB3_NAME="lab-3"
LAB4_NAME="lab-4"
ROLE_ID="devops"
SA_NAME="devops"
MACHINE_TYPE="e2-standard-2"
PERMISSIONS="compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"

RED=$'\033[0;91m'; GREEN=$'\033[0;92m'; YELLOW=$'\033[0;93m'; BLUE=$'\033[0;94m'; CYAN=$'\033[0;96m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

stage(){ echo; echo "${GREEN}${BOLD}=== $1 ===${RESET}"; echo; }
info(){ echo "${BLUE}${BOLD}➜ $1${RESET}"; }
success(){ echo "${GREEN}${BOLD}✅ $1${RESET}"; }
warn(){ echo "${YELLOW}${BOLD}⚠️  $1${RESET}"; }
fail(){ echo "${RED}${BOLD}❌ $1${RESET}"; exit 1; }

clean_value(){ local v="${1:-}"; [[ "$v" == "(unset)" || "$v" == "None" ]] && echo "" || echo "$v"; }
metadata_value(){ curl -sf -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/${1}" 2>/dev/null || true; }
region_from_zone(){ echo "$1" | sed 's/-[a-z]$//'; }

ask(){
  local var="$1" text="$2" def="${3:-}" value="${!1:-}"
  if [[ -z "$value" ]]; then
    if [[ -n "$def" ]]; then
      read -rp "$text [$def]: " value
      value="${value:-$def}"
    else
      read -rp "$text: " value
    fi
    printf -v "$var" '%s' "$value"
  fi
}

run_quiet(){ "$@" >/dev/null 2>&1; }

retry(){
  local attempts="$1" delay="$2" label="$3"; shift 3
  local i
  for ((i=1; i<=attempts; i++)); do
    if "$@"; then
      return 0
    fi
    warn "$label failed attempt $i/$attempts. Retrying in ${delay}s..."
    sleep "$delay"
  done
  fail "$label failed after $attempts attempts."
}

ensure_active_login(){
  local account="$1" label="$2"
  local active
  active="$(clean_value "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1 || true)")"

  echo "Current active account : ${active:-none}"
  echo "Required $label account: $account"

  if [[ "$active" == "$account" ]]; then
    gcloud config set account "$account" --quiet >/dev/null
    success "$label already active."
    return 0
  fi

  warn "$label login required. Login ONLY with: $account"
  echo "Press ENTER, open the URL, allow access, copy code, then paste it here."
  read -r

  while true; do
    export CLOUDSDK_CORE_DISABLE_PROMPTS=0
    if gcloud auth login "$account" --no-launch-browser; then
      export CLOUDSDK_CORE_DISABLE_PROMPTS=1
      gcloud config set account "$account" --quiet >/dev/null
      active="$(clean_value "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1 || true)")"
      if [[ "$active" == "$account" ]]; then
        success "$label login confirmed: $active"
        return 0
      fi
      warn "Wrong active account: $active. Expected: $account"
    else
      export CLOUDSDK_CORE_DISABLE_PROMPTS=1
      warn "Login failed/cancelled."
    fi
    echo "Retry login with correct account: $account"
    read -rp "Press ENTER to retry or CTRL+C to stop... "
  done
}

instance_zone(){
  local project="$1" name="$2"
  gcloud compute instances list --project "$project" --filter="name=($name)" --format="value(zone)" 2>/dev/null | head -n 1 | awk -F/ '{print $NF}'
}

zone_exists(){
  local project="$1" zone="$2"
  [[ -n "$zone" ]] && gcloud compute zones describe "$zone" --project "$project" >/dev/null 2>&1
}

make_instance(){
  local project="$1" name="$2" zone="$3" extra="${4:-}"
  local existing status
  existing="$(clean_value "$(instance_zone "$project" "$name" || true)")"
  if [[ -n "$existing" ]]; then
    warn "$name already exists in $existing. Reusing."
    status="$(gcloud compute instances describe "$name" --project "$project" --zone "$existing" --format='value(status)' 2>/dev/null || true)"
    if [[ "$status" != "RUNNING" ]]; then
      gcloud compute instances start "$name" --project "$project" --zone "$existing" --quiet
    fi
    echo "$existing"
    return 0
  fi

  [[ -n "$zone" ]] || fail "Zone is empty for $name. Enter Zone 2 from Qwiklabs panel."
  zone_exists "$project" "$zone" || fail "Zone $zone is not available in project $project."

  info "Creating $name in $zone..."
  # shellcheck disable=SC2086
  gcloud compute instances create "$name" --project "$project" --zone "$zone" --machine-type "$MACHINE_TYPE" $extra --quiet
  success "$name created in $zone."
  echo "$zone"
}

pick_zone2(){
  local project="$1" given="${2:-}" z region
  if [[ -n "$given" ]]; then echo "$given"; return 0; fi

  # Try Project 2 metadata first. This works after Username 1 authentication.
  z="$(clean_value "$(gcloud compute project-info describe --project "$project" --format='value(commonInstanceMetadata.items[google-compute-default-zone])' 2>/dev/null || true)")"
  if [[ -n "$z" ]]; then echo "$z"; return 0; fi

  region="$(clean_value "$(gcloud compute project-info describe --project "$project" --format='value(commonInstanceMetadata.items[google-compute-default-region])' 2>/dev/null || true)")"
  if [[ -n "$region" ]]; then
    z="$(gcloud compute zones list --project "$project" --filter="name~'^${region}-'" --format='value(name)' 2>/dev/null | head -n 1 || true)"
    if [[ -n "$z" ]]; then echo "$z"; return 0; fi
  fi

  # Use the first listed zone if available.
  z="$(gcloud compute zones list --project "$project" --format='value(name)' 2>/dev/null | head -n 1 || true)"
  if [[ -n "$z" ]]; then echo "$z"; return 0; fi

  # Final safe fallback for Qwiklabs projects. If quota fails later, re-run and enter another zone.
  echo "us-east1-c"
  return 0
}

set_bashrc_var(){
  local key="$1" val="$2"
  touch "$HOME/.bashrc"
  sed -i "/^export ${key}=/d" "$HOME/.bashrc" || true
  printf 'export %s=%q\n' "$key" "$val" >> "$HOME/.bashrc"
  export "$key=$val"
}

ensure_ssh_key(){
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ ! -f "$HOME/.ssh/google_compute_engine" ]]; then
    info "Creating SSH key for gcloud compute ssh..."
    ssh-keygen -t rsa -f "$HOME/.ssh/google_compute_engine" -C "${USER:-gcloud}" -N "" >/dev/null
  fi
}

create_lab4_inside_lab3(){
  local project="$1" zone="$2" lab3="$3" lab4="$4"
  ensure_ssh_key
  info "Waiting for $lab3 SSH..."
  local i
  for ((i=1; i<=15; i++)); do
    if gcloud compute ssh "$lab3" --project "$project" --zone "$zone" --quiet \
      --ssh-flag="-o StrictHostKeyChecking=no" \
      --ssh-flag="-o UserKnownHostsFile=/dev/null" \
      --command="echo ssh-ok" >/dev/null 2>&1; then
      success "$lab3 SSH ready."
      break
    fi
    warn "$lab3 SSH not ready $i/15. Waiting..."
    sleep 12
  done
  [[ "$i" -le 15 ]] || fail "Could not SSH into $lab3."

  local cmd="
set -Eeuo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
echo '--- Running inside lab-3 ---'
gcloud config set project '$project' --quiet || true
gcloud config set compute/zone '$zone' --quiet || true
gcloud auth list || true
gcloud config list || true
if gcloud compute instances describe '$lab4' --project '$project' --zone '$zone' >/dev/null 2>&1; then
  echo '$lab4 already exists in $zone'
else
  gcloud compute instances create '$lab4' --project '$project' --zone '$zone' --machine-type=e2-standard-2 --quiet
fi
gcloud compute instances list --project '$project'
"

  info "Creating $lab4 by SSHing into $lab3..."
  gcloud compute ssh "$lab3" --project "$project" --zone "$zone" --quiet \
    --ssh-flag="-tt" \
    --ssh-flag="-o StrictHostKeyChecking=no" \
    --ssh-flag="-o UserKnownHostsFile=/dev/null" \
    --command="$cmd"
  success "$lab4 command completed from inside $lab3."
}

echo
printf '%b\n' "${CYAN}${BOLD}GSP647 SCRIPT 02 V3: RUN INSIDE centos-clean${RESET}"
echo

META_PROJECT="$(clean_value "$(metadata_value 'project/project-id')")"
ZONE_FULL="$(metadata_value 'instance/zone')"
ZONE1="$(clean_value "$(basename "$ZONE_FULL")")"

if [[ -z "$META_PROJECT" || -z "$ZONE1" ]]; then
  fail "Metadata not detected. Run this inside centos-clean VM SSH, not Cloud Shell."
fi

PROJECT1="$META_PROJECT"
REGION1="$(region_from_zone "$ZONE1")"

ask USER1 "Paste Username 1 email from Qwiklabs"
ask USER2 "Paste Username 2 email from Qwiklabs"
ask PROJECT2 "Paste Project 2 ID from Qwiklabs"
ask ZONE2_INPUT "Paste Zone 2 from Qwiklabs if shown, else press ENTER" ""

SA_EMAIL="${SA_NAME}@${PROJECT2}.iam.gserviceaccount.com"

info "Project 1: $PROJECT1"
info "Project 2: $PROJECT2"
info "Zone 1: $ZONE1"
info "Region 1: $REGION1"
info "Username 1: $USER1"
info "Username 2: $USER2"

gcloud --version | head -n 1 || true

stage "1. Username 1 default config"
gcloud config configurations activate default --quiet >/dev/null 2>&1 || true
gcloud config set project "$PROJECT1" --quiet
gcloud config set compute/region "$REGION1" --quiet
gcloud config set compute/zone "$ZONE1" --quiet
ensure_active_login "$USER1" "Username 1"
gcloud config set account "$USER1" --quiet
gcloud config set project "$PROJECT1" --quiet
gcloud config set compute/region "$REGION1" --quiet
gcloud config set compute/zone "$ZONE1" --quiet
set_bashrc_var PROJECTID2 "$PROJECT2"
set_bashrc_var USERID2 "$USER2"

ZONE2="$(pick_zone2 "$PROJECT2" "$ZONE2_INPUT")"
info "Zone 2 selected: $ZONE2"

stage "2. Create lab-1 and change default zone"
LAB1_ZONE="$(make_instance "$PROJECT1" "$LAB1_NAME" "$ZONE1")"
LAB1_ZONE="$(echo "$LAB1_ZONE" | tail -n 1)"
NEW_ZONE="$(gcloud compute zones list --project "$PROJECT1" --filter="name~'^${REGION1}-'" --format='value(name)' | grep -v "^${LAB1_ZONE}$" | head -n 1 || true)"
NEW_ZONE="${NEW_ZONE:-$LAB1_ZONE}"
gcloud config set compute/zone "$NEW_ZONE" --quiet
gcloud config list
cat ~/.config/gcloud/configurations/config_default || true
success "lab-1 done. Default zone changed to $NEW_ZONE."

stage "3. Create user2 config and login"
gcloud config configurations create user2 --quiet >/dev/null 2>&1 || true
gcloud config configurations activate user2 --quiet
gcloud config set project "$PROJECT1" --quiet
ensure_active_login "$USER2" "Username 2"
gcloud config set account "$USER2" --quiet
gcloud config set project "$PROJECT1" --quiet
gcloud compute instances list --project "$PROJECT1" || true
success "user2 config done."

stage "4. IAM roles on Project 2"
gcloud config configurations activate default --quiet
gcloud config set account "$USER1" --quiet
gcloud config set project "$PROJECT1" --quiet

(sudo yum -y install epel-release >/dev/null 2>&1 && sudo yum -y install jq >/dev/null 2>&1) || warn "jq install skipped; continuing."

gcloud services enable compute.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com --project "$PROJECT1" --quiet >/dev/null 2>&1 || true
gcloud services enable compute.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com --project "$PROJECT2" --quiet >/dev/null 2>&1 || true

retry 3 10 "Bind viewer to Username 2" gcloud projects add-iam-policy-binding "$PROJECT2" --member="user:${USER2}" --role="roles/viewer" --quiet

if gcloud iam roles describe "$ROLE_ID" --project "$PROJECT2" >/dev/null 2>&1; then
  gcloud iam roles update "$ROLE_ID" --project "$PROJECT2" --title="devops" --description="devops" --permissions="$PERMISSIONS" --stage="GA" --quiet
else
  gcloud iam roles create "$ROLE_ID" --project "$PROJECT2" --title="devops" --description="devops" --permissions="$PERMISSIONS" --stage="GA" --quiet
fi

retry 3 10 "Bind iam.serviceAccountUser to Username 2" gcloud projects add-iam-policy-binding "$PROJECT2" --member="user:${USER2}" --role="roles/iam.serviceAccountUser" --quiet
retry 3 10 "Bind custom devops role to Username 2" gcloud projects add-iam-policy-binding "$PROJECT2" --member="user:${USER2}" --role="projects/${PROJECT2}/roles/${ROLE_ID}" --quiet
info "Waiting 35 seconds for IAM propagation..."
sleep 35

stage "5. Create lab-2 as Username 2"
gcloud config configurations activate user2 --quiet
gcloud config set account "$USER2" --quiet
gcloud config set project "$PROJECT2" --quiet
gcloud config set compute/zone "$ZONE2" --quiet
LAB2_ZONE="$(make_instance "$PROJECT2" "$LAB2_NAME" "$ZONE2")"
LAB2_ZONE="$(echo "$LAB2_ZONE" | tail -n 1)"
ZONE2="$LAB2_ZONE"
success "lab-2 done in $ZONE2."

stage "6. Create devops service account and roles"
gcloud config configurations activate default --quiet
gcloud config set account "$USER1" --quiet
gcloud config set project "$PROJECT2" --quiet
gcloud config set compute/zone "$ZONE2" --quiet

if gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT2" >/dev/null 2>&1; then
  warn "Service account exists: $SA_EMAIL"
else
  gcloud iam service-accounts create "$SA_NAME" --display-name="devops" --project "$PROJECT2" --quiet
fi
SA="$(gcloud iam service-accounts list --project "$PROJECT2" --filter="displayName=devops" --format='value(email)' | head -n 1)"
SA="${SA:-$SA_EMAIL}"
set_bashrc_var SA "$SA"

retry 3 10 "Bind serviceAccountUser to devops SA" gcloud projects add-iam-policy-binding "$PROJECT2" --member="serviceAccount:${SA}" --role="roles/iam.serviceAccountUser" --quiet
gcloud projects add-iam-policy-binding "$PROJECT2" --member="serviceAccount:${SA}" --role="roles/compute.instanceAdmin" --quiet || true
gcloud projects add-iam-policy-binding "$PROJECT2" --member="serviceAccount:${SA}" --role="roles/compute.instanceAdmin.v1" --quiet || true
info "Waiting 35 seconds for service account IAM propagation..."
sleep 35

stage "7. Create lab-3 with devops service account"
LAB3_EXTRA="--service-account=${SA} --scopes=https://www.googleapis.com/auth/compute"
LAB3_ZONE="$(make_instance "$PROJECT2" "$LAB3_NAME" "$ZONE2" "$LAB3_EXTRA")"
LAB3_ZONE="$(echo "$LAB3_ZONE" | tail -n 1)"
ZONE2="$LAB3_ZONE"
CURRENT_SA="$(gcloud compute instances describe "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --format='value(serviceAccounts.email)' 2>/dev/null || true)"
if [[ "$CURRENT_SA" != "$SA" ]]; then
  warn "lab-3 has wrong/missing service account. Fixing..."
  STATUS="$(gcloud compute instances describe "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --format='value(status)' || true)"
  [[ "$STATUS" == "RUNNING" ]] && gcloud compute instances stop "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --quiet
  gcloud compute instances set-service-account "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --service-account "$SA" --scopes "https://www.googleapis.com/auth/compute" --quiet
  gcloud compute instances start "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --quiet
fi
success "lab-3 done with service account $SA."

stage "8. SSH into lab-3 and create lab-4"
create_lab4_inside_lab3 "$PROJECT2" "$ZONE2" "$LAB3_NAME" "$LAB4_NAME"

stage "9. Final verification"
echo "Project 1 instances:"
gcloud compute instances list --project "$PROJECT1" || true

echo
echo "Project 2 instances:"
gcloud compute instances list --project "$PROJECT2" || true

echo
echo "Username 2 IAM bindings:"
gcloud projects get-iam-policy "$PROJECT2" --flatten="bindings[].members" --filter="bindings.members=user:${USER2}" --format="table(bindings.role,bindings.members)" || true

echo
echo "devops service account IAM bindings:"
gcloud projects get-iam-policy "$PROJECT2" --flatten="bindings[].members" --filter="bindings.members=serviceAccount:${SA}" --format="table(bindings.role,bindings.members)" || true

echo
echo "lab-3 service account:"
gcloud compute instances describe "$LAB3_NAME" --project "$PROJECT2" --zone "$ZONE2" --format="value(serviceAccounts.email)" || true

echo
info "Waiting 60 seconds for Qwiklabs checker propagation..."
sleep 60

echo
echo "${GREEN}${BOLD}MISSION ACCOMPLISHED. Now click all Check my progress buttons.${RESET}"
