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
echo "${RANDOM_TEXT_COLOR}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP414: BigQuery Partitioned Tables)... ${RESET}"
echo "--------------------------------------------------------------------------------"
echo ""

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
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

echo "${BOLD}${BLUE}[Orbit of Ops] Task 1: Creating 'ecommerce' dataset...${RESET}"
bq mk ecommerce

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Querying web page analytics for 2017 (Non-partitioned)...${RESET}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE date = "20170708"
LIMIT 5
'

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Querying web page analytics for 2018 (Non-partitioned)...${RESET}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE date = "20180708"
LIMIT 5
'

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 2: Creating partitioned table 'partition_by_day'...${RESET}"
bq query --use_legacy_sql=false '
 CREATE OR REPLACE TABLE ecommerce.partition_by_day
 PARTITION BY date_formatted
 OPTIONS(
   description="a table partitioned by date"
 ) AS
 SELECT DISTINCT
 PARSE_DATE("%Y%m%d", date) AS date_formatted,
 fullvisitorId
 FROM `data-to-insights.ecommerce.all_sessions_raw`
'

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 3: Querying the new partitioned table (2016-08-01)...${RESET}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT *
FROM `data-to-insights.ecommerce.partition_by_day`
WHERE date_formatted = "2016-08-01"
'

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Querying the new partitioned table (2018-07-08 - Expecting 0 bytes)...${RESET}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT *
FROM `data-to-insights.ecommerce.partition_by_day`
WHERE date_formatted = "2018-07-08"
'

echo ""
echo "${BOLD}${BLUE}[Orbit of Ops] Task 4: Querying NOAA weather data tables...${RESET}"
bq query --use_legacy_sql=false '
#standardSQL
 SELECT
   DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
   (SELECT ANY_VALUE(name) FROM `bigquery-public-data.noaa_gsod.stations` AS stations
    WHERE stations.usaf = stn) AS station_name,  -- Stations may have multiple names
   prcp
 FROM `bigquery-public-data.noaa_gsod.gsod*` AS weather
 WHERE prcp < 99.9  -- Filter unknown values
   AND prcp > 0      -- Filter stations/days with no precipitation
   AND _TABLE_SUFFIX >= "2018"
 ORDER BY date DESC -- Where has it rained/snowed recently
 LIMIT 10
'

echo ""
echo "${BOLD}${MAGENTA}[Orbit of Ops] Task 5: Creating auto-expiring partitioned table 'days_with_rain'...${RESET}"
# FIX: Updated partition_expiration_days from 60 to 730 per updated lab requirements!
bq query --use_legacy_sql=false '
 CREATE OR REPLACE TABLE ecommerce.days_with_rain
 PARTITION BY date
 OPTIONS (
   partition_expiration_days=730,
   description="weather stations with precipitation, partitioned by day"
 ) AS
 SELECT
   DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
   (SELECT ANY_VALUE(name) FROM `bigquery-public-data.noaa_gsod.stations` AS stations
    WHERE stations.usaf = stn) AS station_name,  -- Stations may have multiple names
   prcp
 FROM `bigquery-public-data.noaa_gsod.gsod*` AS weather
 WHERE prcp < 99.9  -- Filter unknown values
   AND prcp > 0      -- Filter
   AND _TABLE_SUFFIX >= "2018"
'

# ==============================================================================
# COMPLETION
# ==============================================================================
echo ""
echo "--------------------------------------------------------------------------------"
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You've successfully completed the lab!${RESET}"
        "${BLUE}Outstanding! Your dedication has brought you success!${RESET}"
        "${MAGENTA}Great work! You're one step closer to mastering this!${RESET}"
        "${RED}Fantastic effort! You've earned this achievement!${RESET}"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "🎉 ${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}
random_congrats
echo "${CYAN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your manual.${RESET}"
echo "--------------------------------------------------------------------------------"
