#!/bin/bash

clear

# ==============================================================================
# Color Variables & Branding
# ==============================================================================
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}

echo "${CYAN}${BOLD}"
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
echo "${RESET}"
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP416: JSON, Arrays, and Structs)... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS & AUTO-FETCH
# ==============================================================================
echo "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

echo "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo ""

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo "${BOLD}${BLUE}[Orbit of Ops] Tasks 1 & 2: Creating 'fruit_store' dataset & loading JSON data...${RESET}"
bq mk --location=US fruit_store

# FIX: Updated the GCS source path to match the new spls/gsp416 bucket location
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --autodetect \
  ${PROJECT_ID}:fruit_store.fruit_details \
  gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/shopping_cart.json

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 3: Running ARRAY_AGG() Query...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(DISTINCT v2ProductName) AS products_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT v2ProductName)) AS distinct_products_viewed,
  ARRAY_AGG(DISTINCT pageTitle) AS pages_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT pageTitle)) AS distinct_pages_viewed
  FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 4: Running UNNEST() Query...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT DISTINCT
  visitId,
  h.page.pageTitle
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`,
UNNEST(hits) AS h
WHERE visitId = 1501570398
LIMIT 10
EOF

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 6: Creating 'racing' dataset & loading STRUCT/ARRAY JSON...${RESET}"
bq mk --location=US racing

cat > schema.json <<'EOF'
[
    {
        "name": "race",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "participants",
        "type": "RECORD",
        "mode": "REPEATED",
        "fields": [
            {
                "name": "name",
                "type": "STRING",
                "mode": "NULLABLE"
            },
            {
                "name": "splits",
                "type": "FLOAT",
                "mode": "REPEATED"
            }
        ]
    }
]
EOF

# FIX: Updated the GCS source path to match the new spls/gsp416 bucket location
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --schema=schema.json \
  ${PROJECT_ID}:racing.race_results \
  gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/race_results.json

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 7: Querying racer counts (STRUCT)...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT COUNT(p.name) AS racer_count
FROM racing.race_results AS r, UNNEST(r.participants) AS p
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 8: Unpacking arrays and summing race times...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT
  p.name,
  SUM(split_times) as total_race_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_times
WHERE p.name LIKE 'R%'
GROUP BY p.name
ORDER BY total_race_time ASC;
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 9: Filtering within array values...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT
  p.name,
  split_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_time
WHERE split_time = 23.2;
EOF

# ==============================================================================
# COMPLETION
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
function random_congrats() {
    MESSAGES=(
        "Congratulations For Completing The Lab! Keep up the great work!"
        "Well done! Your hard work and effort have paid off!"
        "Amazing job! You've successfully completed the lab!"
        "Outstanding! Your dedication has brought you success!"
        "Great work! You're one step closer to mastering this!"
        "Fantastic effort! You've earned this achievement!"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${GREEN}${BOLD}${MESSAGES[$RANDOM_INDEX]}${RESET}"
}
random_congrats
echo "${CYAN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your manual.${RESET}"
echo "--------------------------------------------------------------------------------"
