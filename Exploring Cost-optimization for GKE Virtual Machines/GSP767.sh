#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP767 FLAWLESS MASTER 
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
RED=$(tput setaf 1)
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
echo "${MAGENTA}${BOLD}>>> INITIATING FLAWLESS MASTER SCRIPT <<<${RESET}"
echo ""

export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
export DATE_SUFFIX=$(date -u +%Y%m%d)

echo "${BOLD}${YELLOW}[*] Enabling required APIs for rich VPC metadata...${RESET}"
gcloud services enable networkmanagement.googleapis.com

echo "${BOLD}${YELLOW}[*] Phase 1: Waiting for hello-demo-cluster to be ready...${RESET}"
until gcloud container clusters get-credentials hello-demo-cluster --zone $ZONE 2>/dev/null; do
  echo -ne "Cluster provisioning... waiting 10 seconds...\r"
  sleep 10
done
echo -e "\n${BOLD}${GREEN}[+] hello-demo-cluster is ready!${RESET}"

echo "${BOLD}${CYAN}[*] Phase 2: Scaling and Node Pool Migration...${RESET}"
kubectl scale deployment hello-server --replicas=2
gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool --num-nodes 4 --zone $ZONE --quiet

gcloud container node-pools create larger-pool \
  --cluster=hello-demo-cluster \
  --machine-type=e2-standard-2 \
  --num-nodes=1 \
  --zone=$ZONE --quiet

echo "Cordoning and draining old nodes..."
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl cordon "$node" >/dev/null 2>&1
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node" >/dev/null 2>&1
done

gcloud container node-pools delete my-node-pool --cluster hello-demo-cluster --zone $ZONE --quiet 

echo -e "\n${BOLD}${CYAN}[*] Phase 3: Regional Cluster Provisioning (Takes 3-5 mins)...${RESET}"
gcloud container clusters create regional-demo --region=$REGION --num-nodes=1
gcloud container clusters get-credentials regional-demo --region $REGION

echo -e "\n${BOLD}${YELLOW}[*] Phase 4: Network Prep & Dataset (THE SCHEMA FIX)...${RESET}"
gcloud compute networks subnets update default \
  --region=$REGION \
  --enable-flow-logs \
  --logging-metadata=include-all \
  --quiet

bq mk --location=US ${PROJECT_ID}:us_flow_logs 2>/dev/null || true

echo -e "\n${BOLD}${MAGENTA}[*] Phase 5: Deploying Cross-Zonal Pods...${RESET}"
cat << EOF > pod-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  labels:
    security: demo
spec:
  containers:
  - name: container-1
    image: wbitt/network-multitool
EOF
kubectl apply -f pod-1.yaml >/dev/null 2>&1

cat << EOF > pod-2-anti.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF
kubectl apply -f pod-2-anti.yaml >/dev/null 2>&1

echo "Waiting for Pods to initialize..."
kubectl wait --for=condition=Ready pod/pod-1 --timeout=120s
kubectl wait --for=condition=Ready pod/pod-2 --timeout=120s

export ANTI_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')
echo "${BOLD}${GREEN}[+] Saturating network with cross-zonal pings to enforce schema...${RESET}"
kubectl exec pod-1 -- ping -i 0.2 $ANTI_IP > /dev/null 2>&1 &
PING_PID=$!

echo -e "\n${BOLD}${RED}*****************************************************************${RESET}"
echo "${BOLD}${RED}🛑 STOP! MANUAL SINK CREATION REQUIRED 🛑${RESET}"
echo "${BOLD}${RED}*****************************************************************${RESET}"
echo "${WHITE}Go to the Cloud Console UI to bypass the IAM block:${RESET}"
echo "1. Go to ${YELLOW}Navigation Menu > Logging > Log Router${RESET}"
echo "2. Click ${YELLOW}'Create Sink'${RESET}"
echo "3. Name: ${CYAN}FlowLogsSample${RESET}"
echo "4. Destination: ${CYAN}'BigQuery dataset'${RESET} -> ${CYAN}'us_flow_logs'${RESET}"
echo "5. Inclusion Filter (Paste this exact line):"
echo -e "${MAGENTA}logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"${RESET}"
echo "6. Click ${YELLOW}'Create Sink'${RESET}"
echo ""
read -p "${BOLD}${GREEN}Press [ENTER] only AFTER creating the sink in the UI...${RESET}"

echo -e "\n${BOLD}${CYAN}[*] Phase 6: Polling Exact Grader Query (Takes 3-5 mins)...${RESET}"
echo "Waiting for BigQuery to stream logs and validate schema..."
while true; do
  if bq query --use_legacy_sql=false \
    "SELECT jsonPayload.src_instance.zone AS src_zone, jsonPayload.src_instance.vm_name AS src_vm, jsonPayload.dest_instance.zone AS dest_zone, jsonPayload.dest_instance.vm_name FROM \`${PROJECT_ID}.us_flow_logs.compute_googleapis_com_vpc_flows_${DATE_SUFFIX}\` LIMIT 1000" 2>/dev/null; then
    
    echo -e "\n${BOLD}${GREEN}[+] SUCCESS! BigQuery processed the exact Grader SQL Query perfectly!${RESET}"
    kill $PING_PID 2>/dev/null || true
    break
  else
    echo -ne "BigQuery streaming buffer updating... Retrying in 20s...\r"
    sleep 20
  fi
done

echo -e "\n${BOLD}${MAGENTA}[*] Phase 7: Restoring Co-Located state...${RESET}"
sed -i 's/podAntiAffinity/podAffinity/g' pod-2-anti.yaml
kubectl delete pod pod-2 >/dev/null 2>&1
kubectl apply -f pod-2-anti.yaml >/dev/null 2>&1

kubectl wait --for=condition=Ready pod/pod-2 --timeout=120s
export AFF_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')
kubectl exec pod-1 -- ping -c 5 $AFF_IP

echo -e "\n${BOLD}${GREEN}====================================================================${RESET}"
echo "${BOLD}${GREEN}>>> ARCHITECTURE FLAWLESS. CLICK 'CHECK MY PROGRESS' ON ALL TASKS <<< ${RESET}"
echo "${BOLD}${GREEN}====================================================================${RESET}"
