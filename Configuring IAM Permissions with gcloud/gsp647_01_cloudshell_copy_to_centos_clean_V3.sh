#!/usr/bin/env bash
# GSP647 Script 01 V3 - Run this in Cloud Shell only.
# It copies the VM script to centos-clean.

set -Eeuo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

SCRIPT="gsp647_02_run_inside_centos_clean_V3.sh"
DEST="/tmp/gsp647_02_run_inside_centos_clean_V3.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "❌ $SCRIPT not found in Cloud Shell current folder. Upload it first."
  exit 1
fi

PROJECT1="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT1" || "$PROJECT1" == "(unset)" ]]; then
  echo "❌ Project not detected. Open Cloud Shell after starting the lab."
  exit 1
fi

CENTOS_ZONE="$(gcloud compute instances list   --project "$PROJECT1"   --filter="name=centos-clean"   --format="value(zone)" | head -n 1 | awk -F/ '{print $NF}')"

if [[ -z "$CENTOS_ZONE" ]]; then
  echo "❌ centos-clean VM not found. Make sure the lab is started."
  exit 1
fi

echo "Project 1: $PROJECT1"
echo "centos-clean zone: $CENTOS_ZONE"
echo "Copying $SCRIPT to centos-clean:$DEST ..."

chmod +x "$SCRIPT"
gcloud compute scp "$SCRIPT" "centos-clean:$DEST"   --project "$PROJECT1"   --zone "$CENTOS_ZONE"   --quiet

gcloud compute ssh centos-clean   --project "$PROJECT1"   --zone "$CENTOS_ZONE"   --quiet   --command "chmod +x '$DEST' && ls -l '$DEST'"

echo
echo "✅ Copied successfully."
echo "Now open centos-clean SSH manually and run:"
echo "$DEST"
