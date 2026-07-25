#!/bin/bash

# Retrieve the current Qwiklabs Project ID
PROJECT_ID=$(gcloud config get-value project)

# The principal email provided in your instructions for Task 3
# (Update this if Qwiklabs generated a different email for the second student in your active session)
PRINCIPAL_EMAIL="student-03-ddccb28825cf@qwiklabs.net"

echo "========================================"
echo " Starting Qwiklabs Automation Script... "
echo "========================================"

echo ""
echo "--> Task 3: Granting Viewer role to $PRINCIPAL_EMAIL"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$PRINCIPAL_EMAIL" \
    --role="roles/viewer" \
    --condition=None

echo ""
echo "--> Task 4: Enabling the Dialogflow API"
gcloud services enable dialogflow.googleapis.com

echo ""
echo "========================================"
echo " Tasks completed successfully!          "
echo " Go click 'Check my progress' now.      "
echo "========================================"
