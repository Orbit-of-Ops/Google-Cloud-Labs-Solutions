#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP343 FLAWLESS INTERACTIVE MASTER 
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo "${RESET}"
echo "${MAGENTA}${BOLD}>>> INITIATING GSP343 CHALLENGE LAB MASTER SCRIPT <<<${RESET}"
echo ""

# ==============================================================================
# INTERACTIVE VARIABLE SETUP
# ==============================================================================
echo "${BOLD}${YELLOW}--- LAB CONFIGURATION SETUP ---${RESET}"

# 1. Zone Auto-Detection
AUTO_ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [[ -n "$AUTO_ZONE" ]]; then
    echo -e "Detected default zone: ${CYAN}$AUTO_ZONE${RESET}"
    read -p "Press [ENTER] to use this zone, or type a new zone from your lab instructions: " INPUT_ZONE
    ZONE=${INPUT_ZONE:-$AUTO_ZONE}
else
    echo -e "${WHITE}Look at the ${BOLD}'Challenge scenario'${RESET}${WHITE} section in your lab instructions.${RESET}"
    read -p "Enter the <Zone> (e.g., us-central1-a): " ZONE
fi

# 2. Cluster Name
echo -e "\n${WHITE}Look at ${BOLD}Task 1${RESET}${WHITE} in your lab instructions.${RESET}"
read -p "Enter the exact Cluster Name (e.g., team-resource-123): " CLUSTER_NAME

# 3. Node Pool Name
echo -e "\n${WHITE}Look at ${BOLD}Task 2${RESET}${WHITE} in your lab instructions.${RESET}"
read -p "Enter the exact Node Pool Name (e.g., pool-resource-123): " POOL_NAME

# 4. Max Replicas
echo -e "\n${WHITE}Look at ${BOLD}Task 4${RESET}${WHITE} in your lab instructions.${RESET}"
read -p "Enter the Max Replicas number for the frontend deployment (e.g., 10): " MAX_REPLICAS

echo -e "\n${BOLD}${GREEN}Configuration Saved. Commencing Deployment Sequence...${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project)
gcloud config set compute/zone $ZONE >/dev/null 2>&1

# ==============================================================================
# EXECUTION PHASE
# ==============================================================================

echo "${BOLD}${CYAN}[*] Task 1: Creating Cluster (rapid channel) & Deploying App...${RESET}"
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --num-nodes=2 \
    --release-channel=rapid \
    --quiet

kubectl create namespace dev
kubectl create namespace prod

git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo
kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev

echo "${YELLOW}Waiting for deployments to initialize (Takes ~2-3 mins)...${RESET}"
kubectl wait --for=condition=Available deployment/frontend --namespace dev --timeout=300s

echo -e "\n${BOLD}${MAGENTA}[*] Task 2: Creating Optimized Node Pool & Migrating Workloads...${RESET}"
gcloud container node-pools create $POOL_NAME \
    --cluster=$CLUSTER_NAME \
    --machine-type=custom-2-3584 \
    --num-nodes=2 \
    --zone=$ZONE \
    --quiet

echo "${YELLOW}Cordoning and draining default-pool...${RESET}"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl cordon "$node" >/dev/null 2>&1
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node" >/dev/null 2>&1
done

echo "${YELLOW}Deleting default-pool...${RESET}"
gcloud container node-pools delete default-pool --cluster=$CLUSTER_NAME --zone=$ZONE --quiet

echo -e "\n${BOLD}${CYAN}[*] Task 3: Applying Frontend Update (PDB & Image)...${RESET}"
kubectl create poddisruptionbudget onlineboutique-frontend-pdb \
    --selector app=frontend \
    --min-available 1 \
    --namespace dev

kubectl patch deployment frontend -n dev --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value":"Always"}
]'
sleep 5

echo -e "\n${BOLD}${MAGENTA}[*] Task 4: Autoscaling Frontend, Cluster, and Recommendation Service...${RESET}"
kubectl autoscale deployment frontend \
    --cpu-percent=50 \
    --min=1 \
    --max=$MAX_REPLICAS \
    --namespace dev

gcloud beta container clusters update $CLUSTER_NAME \
    --enable-autoscaling \
    --min-nodes 1 \
    --max-nodes 6 \
    --zone=$ZONE \
    --quiet

kubectl autoscale deployment recommendationservice \
    --cpu-percent=50 \
    --min=1 \
    --max=5 \
    --namespace dev

echo -e "\n${BOLD}${GREEN}====================================================================${RESET}"
echo "${BOLD}${GREEN}>>> ALL TASKS COMPLETE! YOU CAN NOW CLICK 'CHECK MY PROGRESS' <<< ${RESET}"
echo "${BOLD}${GREEN}====================================================================${RESET}"
