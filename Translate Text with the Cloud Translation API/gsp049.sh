#!/bin/bash

# ==============================================================================
# Orbit of Ops - API Key Generator
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

echo "${YELLOW_TEXT}--> Enabling API Keys Service...${RESET_FORMAT}"
gcloud services enable apikeys.googleapis.com

echo "${BLUE_TEXT}--> Creating API Key 'orbit'...${RESET_FORMAT}"
# Using GA commands to prevent deprecation errors
gcloud services api-keys create --display-name="orbit"

echo "${BLUE_TEXT}--> Retrieving API Key...${RESET_FORMAT}"
KEY_NAME=$(gcloud services api-keys list --format="value(name)" --filter="displayName=orbit" --limit=1)
API_KEY=$(gcloud services api-keys get-key-string "$KEY_NAME" --format="value(keyString)")

echo
echo "${GREEN_TEXT}${BOLD_TEXT}✅ Your API Key is: ${YELLOW_TEXT}$API_KEY${RESET_FORMAT}"
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
