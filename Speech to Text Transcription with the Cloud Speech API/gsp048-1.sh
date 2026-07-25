#!/bin/bash

# ==============================================================================
# Orbit of Ops - Cloud Speech API (Create Key & English Audio)
# ==============================================================================

# Define color variables
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
CYAN_TEXT=$'\033[0;96m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Welcome Banner
echo "${CYAN_TEXT}${BOLD_TEXT}╔════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}               ORBIT OF OPS - CLOUD SPEECH LAB           ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}          Elevating your Cloud and DevOps Journey        ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}╚════════════════════════════════════════════════════════╝${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}🚀 === INITIATING AUTOMATION SEQUENCE ===${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}--> Generating execution script for VM...${RESET_FORMAT}"

cat > prepare_disk.sh <<'EOF_END'
#!/bin/bash
echo "--> Enabling API Keys Service..."
gcloud services enable apikeys.googleapis.com

echo "--> Creating API Key 'awesome' with Speech API restrictions..."
gcloud services api-keys create --display-name="awesome" --api-target=service=speech.googleapis.com

echo "--> Retrieving API Key..."
KEY_NAME=$(gcloud services api-keys list --format="value(name)" --filter="displayName=awesome" --limit=1)
API_KEY=$(gcloud services api-keys get-key-string "$KEY_NAME" --format="value(keyString)")

echo "--> Generating Speech-to-Text JSON request (English)..."
cat > request.json <<EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/brooklyn_bridge.flac"
  }
}
EOF

echo "--> Polling Cloud Speech API until Key propagates (this can take 1 to 4 minutes)..."
while true; do
    # Make the API call, save output to result.json, and capture ONLY the HTTP status code
    HTTP_STATUS=$(curl -s -o result.json -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary @request.json "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}")
    
    if [ "$HTTP_STATUS" == "200" ]; then
        echo -e "\n--> Success. API Key is active and transcription is saved to result.json."
        cat result.json
        echo
        break
    else
        echo -ne "--> Key not ready yet (HTTP $HTTP_STATUS). Retrying in 10 seconds...\033[0K\r"
        sleep 10
    fi
done
EOF_END

echo "${BLUE_TEXT}--> Finding VM Zone...${RESET_FORMAT}"
export ZONE=$(gcloud compute instances list --filter="name=linux-instance" --format="value(zone)")

echo "${BLUE_TEXT}--> Copying script to linux-instance...${RESET_FORMAT}"
gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

echo "${BLUE_TEXT}--> Executing script on linux-instance...${RESET_FORMAT}"
gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

# Checkpoint Banner
echo
echo "${CYAN_TEXT}${BOLD_TEXT}╔══════════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}   ⚠️  NOW: Check Your Score Up To Task 3 Then Process Next ⚠️  ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}╚══════════════════════════════════════════════════════════════╝${RESET_FORMAT}"
echo
echo "${BLUE_TEXT}${BOLD_TEXT}🚀 Keep exploring the Orbit of Ops${RESET_FORMAT}"
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@orbitofops${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Please Subscribe to the channel for more Cloud and DevOps videos${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe${RESET_FORMAT}"
echo
