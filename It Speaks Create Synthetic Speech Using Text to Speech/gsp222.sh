#!/bin/bash

# ==============================================================================
# Orbit of Ops - Text-to-Speech Lab Setup
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
echo "${CYAN_TEXT}${BOLD_TEXT}             ORBIT OF OPS - TEXT TO SPEECH LAB           ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}          Elevating your Cloud and DevOps Journey        ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}╚════════════════════════════════════════════════════════╝${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}🚀 === INITIATING AUTOMATION SEQUENCE ===${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}--> Authenticating and setting Project ID...${RESET_FORMAT}"
gcloud auth list
export PROJECT_ID=$(gcloud config get-value project)
echo "${GREEN_TEXT}Project ID set to: $PROJECT_ID${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}--> Enabling Text-to-Speech API...${RESET_FORMAT}"
gcloud services enable texttospeech.googleapis.com
echo

echo "${YELLOW_TEXT}--> Installing and configuring Python Virtual Environment...${RESET_FORMAT}"
sudo apt-get install -y virtualenv
python3 -m venv venv
source venv/bin/activate
echo "${GREEN_TEXT}Virtual environment activated.${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}--> Creating Service Account 'tts-qwiklab'...${RESET_FORMAT}"
gcloud iam service-accounts create tts-qwiklab
echo

echo "${YELLOW_TEXT}--> Generating Service Account Keys...${RESET_FORMAT}"
gcloud iam service-accounts keys create tts-qwiklab.json --iam-account tts-qwiklab@$PROJECT_ID.iam.gserviceaccount.com
echo

echo "${YELLOW_TEXT}--> Setting up Google Application Credentials...${RESET_FORMAT}"
export GOOGLE_APPLICATION_CREDENTIALS=tts-qwiklab.json
echo "${GREEN_TEXT}Credentials linked to tts-qwiklab.json.${RESET_FORMAT}"
echo

# Completion Banner
echo "${CYAN_TEXT}${BOLD_TEXT}╔════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}             ALL TASKS COMPLETED SUCCESSFULLY             ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}╚════════════════════════════════════════════════════════╝${RESET_FORMAT}"
echo
echo "${BLUE_TEXT}${BOLD_TEXT}🚀 Keep exploring the Orbit of Ops${RESET_FORMAT}"
echo "${RED_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@orbitofops${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Please Subscribe to the channel for more Cloud and DevOps videos${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Don't forget to Like, Share and Subscribe${RESET_FORMAT}"
echo
