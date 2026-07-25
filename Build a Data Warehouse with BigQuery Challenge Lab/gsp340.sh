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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP340: Build a Data Warehouse Challenge)... ${RESET}"
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
# DYNAMIC USER INPUTS FOR CHALLENGE LAB
# ==============================================================================
echo "--------------------------------------------------------------------------------"
echo "${BOLD}${MAGENTA}⚠️  ATTENTION: CHALLENGE LAB VARIABLES REQUIRED ⚠️${RESET}"
echo "${BOLD}${WHITE}Please check Task 1 in your Qwiklabs manual and provide the following:${RESET}"

read -p "${BOLD}${CYAN}Enter the partition expiration days (e.g., 2175): ${RESET}" EXPIRE_DAYS

echo ""
echo "${BOLD}${YELLOW}For the countries, DO NOT use double quotes. Just use single quotes and commas.${RESET}"
read -p "${BOLD}${CYAN}Enter Excluded Countries EXACTLY like this -> 'GBR', 'BRA', 'CAN', 'USA' : ${RESET}" EXCLUDED_COUNTRIES

# SAFEGUARD: Strip any accidental double-quotes the user might type
EXCLUDED_COUNTRIES=$(echo "$EXCLUDED_COUNTRIES" | tr -d '"')

echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'covid' schema & oxford_policy_tracker table...${RESET}"
bq query --use_legacy_sql=false <<EOF
CREATE SCHEMA IF NOT EXISTS covid;

CREATE OR REPLACE TABLE covid.oxford_policy_tracker
PARTITION BY date
OPTIONS(
    partition_expiration_days=$EXPIRE_DAYS
) AS
SELECT *
FROM \`bigquery-public-data.covid19_govt_response.oxford_policy_tracker\`
WHERE alpha_3_code NOT IN ($EXCLUDED_COUNTRIES);
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 2: Populating mobility record data (Fixing STRUCT mapping)...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
UPDATE `covid_data.consolidate_covid_tracker_data` t0
SET mobility = STRUCT(
  t1.avg_retail AS avg_retail,
  t1.avg_grocery AS avg_grocery,
  t1.avg_parks AS avg_parks,
  t1.avg_transit AS avg_transit,
  t1.avg_workplace AS avg_workplace,
  t1.avg_residential AS avg_residential
)
FROM (
  SELECT country_region, date,
    AVG(retail_and_recreation_percent_change_from_baseline) as avg_retail,
    AVG(grocery_and_pharmacy_percent_change_from_baseline) as avg_grocery,
    AVG(parks_percent_change_from_baseline) as avg_parks,
    AVG(transit_stations_percent_change_from_baseline) as avg_transit,
    AVG(workplaces_percent_change_from_baseline) as avg_workplace,
    AVG(residential_percent_change_from_baseline) as avg_residential
  FROM `bigquery-public-data.covid19_google_mobility.mobility_report`
  GROUP BY country_region, date
) t1
WHERE t0.date = t1.date AND t0.country_name = t1.country_region;
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 3: Querying missing population & country_area data...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
SELECT country_name 
FROM `covid_data.oxford_policy_tracker_worldwide` 
WHERE population IS NULL
UNION ALL
SELECT country_name 
FROM `covid_data.oxford_policy_tracker_worldwide` 
WHERE country_area IS NULL
ORDER BY country_name;
EOF

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 4: Creating 'pop_data_2019' table...${RESET}"
bq query --use_legacy_sql=false <<'EOF'
CREATE OR REPLACE TABLE `covid_data.pop_data_2019` AS
SELECT * 
FROM `bigquery-public-data.covid19_ecdc.covid_19_geographic_distribution_worldwide`;
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
