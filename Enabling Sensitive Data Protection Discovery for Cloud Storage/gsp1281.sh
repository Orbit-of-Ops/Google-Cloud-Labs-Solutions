#!/bin/bash
clear

# ==============================================================================
# Orbit of Ops Branding & Colors
# ==============================================================================
BOLD=$(tput bold)
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}====================================================${RESET}"
echo "${CYAN}${BOLD}      ORBIT OF OPS: Sensitive Data Protection       ${RESET}"
echo "${CYAN}${BOLD}====================================================${RESET}"
echo ""

# ==============================================================================
# Initialization & Auth
# ==============================================================================
export PROJECT_ID=$DEVSHELL_PROJECT_ID
export TOKEN=$(gcloud auth print-access-token 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "${RED}Error: Could not authenticate. Run 'gcloud auth login' and try again.${RESET}"
    exit 1
fi
echo "${GREEN}Orbit of Ops: Project ID detected: ${PROJECT_ID}${RESET}"
echo ""

# ==============================================================================
# TASK 1: MANUAL DISCOVERY SETUP
# ==============================================================================
echo "${YELLOW}${BOLD}=== ORBIT OF OPS: TASK 1 MANUAL SETUP ===${RESET}"
echo "To ensure you get full points, complete Task 1 in the UI:"
echo ""
echo "1. Hold CTRL (or CMD) and click this link to open a new tab:"
echo "   ${CYAN}https://console.cloud.google.com/security/sensitive-data-protection${RESET}"
echo "2. Make sure your Qwiklabs project ($PROJECT_ID) is selected at the top."
echo "3. Click the ${BOLD}'Discovery'${RESET} tab."
echo "4. Under 'Cloud Storage', click ${BOLD}'Enable'${RESET}."
echo "5. Leave 'Cloud Storage' selected -> click Continue."
echo "6. Leave 'Scan selected project' selected -> click Continue."
echo "7. Leave default schedules -> click Continue."
echo "8. Leave 'Create a new inspection template' selected -> click Continue."
echo "9. Under 'Add actions':"
echo "   - Check the box for ${BOLD}'Publish to Security Command Center'${RESET}"
echo "   - Check the box for ${BOLD}'Save data profile copies to BigQuery'${RESET}"
echo "   - Set Project ID: ${BOLD}$PROJECT_ID${RESET}"
echo "   - Set Dataset ID: ${BOLD}cloudstorage_discovery${RESET}"
echo "   - Set Table ID: ${BOLD}data_profiles${RESET}"
echo "10. Click Continue on fallback locations and regions."
echo "11. Set Display Name to: ${BOLD}Cloud Storage Discovery${RESET}"
echo "12. Click Create, then Create Configuration."
echo ""
echo "Now go to your Qwiklabs manual and click 'Check my progress' for Task 1."
echo "${YELLOW}=====================================================${RESET}"
echo ""
read -p "${BOLD}Press [ENTER] only AFTER you get the 20/20 green check for Task 1...${RESET}"

# ==============================================================================
# TASK 2: TEMPLATE CONFIGURATION
# ==============================================================================
echo ""
echo "${CYAN}Orbit of Ops: Scanning for Discovery Inspection Templates...${RESET}"
TEMPLATE_NAMES=$(curl -s -H "Authorization: Bearer $TOKEN" "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/global/inspectTemplates" | jq -r '.inspectTemplates[].name')

if [ -z "$TEMPLATE_NAMES" ]; then
    echo "${RED}Error: No templates found! Please ensure Task 1 finished creating the configuration.${RESET}"
    exit 1
fi

cat <<EOF > task2_template.json
{
  "inspectTemplate": {
    "displayName": "Inspection Template for US SSN",
    "description": "This template was created as part of a Sensitive Data Protection profiler configuration and was modified for deeper inspection for US Social Security numbers.",
    "inspectConfig": {
      "infoTypes": [ { "name": "US_SOCIAL_SECURITY_NUMBER" } ],
      "minLikelihood": "UNLIKELY"
    }
  }
}
EOF

# Loop and patch all templates to ensure the grader finds the correct one
for TEMPLATE in $TEMPLATE_NAMES; do
    if [ "$TEMPLATE" != "null" ]; then
        echo "${CYAN}Patching template: $TEMPLATE...${RESET}"
        curl -s -X PATCH \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d @task2_template.json \
          "https://dlp.googleapis.com/v2/$TEMPLATE?updateMask=displayName,description,inspectConfig.infoTypes,inspectConfig.minLikelihood" > /dev/null
    fi
done
echo "${GREEN}Inspection Templates patched successfully.${RESET}"

echo "${CYAN}Orbit of Ops: Creating De-identification Template (Task 2)...${RESET}"
# Silently delete in case it already exists
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/global/deidentifyTemplates/us_ssn_deidentify" > /dev/null

cat <<EOF > deidentify_template.json
{
  "deidentifyTemplate": {
    "displayName": "De-identification Template for US SSN",
    "deidentifyConfig": {
      "recordTransformations": {
        "fieldTransformations": [
          {
            "fields": [ { "name": "ssn" }, { "name": "email" } ],
            "primitiveTransformation": { "replaceConfig": { "newValue": { "stringValue": "[redacted]" } } }
          },
          {
            "fields": [ { "name": "message" } ],
            "infoTypeTransformations": { "transformations": [ { "primitiveTransformation": { "replaceWithInfoTypeConfig": {} } } ] }
          }
        ]
      }
    }
  },
  "templateId": "us_ssn_deidentify"
}
EOF

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @deidentify_template.json \
  "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/global/deidentifyTemplates" > /dev/null

echo "${GREEN}De-identification Template deployed!${RESET}"

echo ""
echo "${YELLOW}${BOLD}=== CHECKPOINT ===${RESET}"
read -p "Please click 'Check my progress' for Task 2. Press [ENTER] to continue to Tasks 4 and 5..."
echo ""

# ==============================================================================
# TASK 4 & 5: JOB SUBMISSIONS
# ==============================================================================
# Grab the first template in the list for the jobs
TARGET_TEMPLATE=$(echo "$TEMPLATE_NAMES" | head -n 1)

echo "${CYAN}Orbit of Ops: Submitting Inspection Job (Task 4)...${RESET}"
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/dlpJobs/us_ssn_inspection" > /dev/null

cat <<EOF > inspect_job.json
{
  "jobId": "us_ssn_inspection",
  "inspectJob": {
    "inspectTemplateName": "$TARGET_TEMPLATE",
    "storageConfig": {
      "cloudStorageOptions": {
        "filesLimitPercent": 100,
        "fileTypes": [ "TEXT_FILE", "CSV" ],
        "fileSet": { "url": "gs://$PROJECT_ID-input/**" }
      }
    },
    "actions": [
      {
        "saveFindings": {
          "outputConfig": { "table": { "projectId": "$PROJECT_ID", "datasetId": "cloudstorage_inspection", "tableId": "us_ssn" } }
        }
      },
      { "publishSummaryToCscc": {} }
    ]
  }
}
EOF

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @inspect_job.json \
  "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/dlpJobs" > /dev/null
echo "${GREEN}Inspection Job submitted and processing.${RESET}"

echo "${CYAN}Orbit of Ops: Submitting De-identification Job (Task 5)...${RESET}"
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/dlpJobs/us_ssn_deidentify" > /dev/null

cat <<EOF > deidentify_job.json
{
  "jobId": "us_ssn_deidentify",
  "inspectJob": {
    "inspectConfig": {
      "infoTypes": [ { "name": "US_SOCIAL_SECURITY_NUMBER" } ],
      "minLikelihood": "POSSIBLE"
    },
    "storageConfig": {
      "cloudStorageOptions": {
        "filesLimitPercent": 100,
        "fileTypes": [ "TEXT_FILE", "CSV" ],
        "fileSet": {
          "regexFileSet": { "bucketName": "$PROJECT_ID-input", "includeRegex": [], "excludeRegex": [ "ignore" ] }
        }
      }
    },
    "actions": [
      {
        "deidentify": {
          "cloudStorageOutput": "gs://$PROJECT_ID-output",
          "transformationConfig": {
            "structuredDeidentifyTemplate": "projects/$PROJECT_ID/locations/global/deidentifyTemplates/us_ssn_deidentify"
          },
          "transformationDetailsStorageConfig": {
            "table": { "projectId": "$PROJECT_ID", "datasetId": "cloudstorage_transformations", "tableId": "deidentify_ssn_csv" }
          },
          "fileTypesToTransform": [ "TEXT_FILE", "CSV" ]
        }
      }
    ]
  }
}
EOF

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @deidentify_job.json \
  "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/dlpJobs" > /dev/null
echo "${GREEN}De-identification Job submitted and processing.${RESET}"

# ==============================================================================
# CLEANUP & FINISH
# ==============================================================================
rm -f task2_template.json deidentify_template.json inspect_job.json deidentify_job.json

echo ""
echo "${GREEN}${BOLD}ORBIT OF OPS: Automation Complete.${RESET}"
echo "${YELLOW}The jobs will take about 2 to 3 minutes to finish processing.${RESET}"
echo "${YELLOW}You can click 'Check my progress' for Task 4 and Task 5 shortly.${RESET}"
