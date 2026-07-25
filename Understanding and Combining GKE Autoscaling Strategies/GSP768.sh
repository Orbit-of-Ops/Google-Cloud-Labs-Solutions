#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GSP768 FLAWLESS MASTER SCRIPT
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
echo "${MAGENTA}${BOLD}>>> INITIATING GSP768 AUTOSCALING MASTER SCRIPT <<<${RESET}"
echo ""

# Fetch zone dynamically to avoid manual input hanging the script
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [ -z "$ZONE" ]; then
    export ZONE="us-central1-a"
fi
gcloud config set compute/zone $ZONE >/dev/null 2>&1
echo "${BOLD}${GREEN}[+] Zone successfully configured to: $ZONE${RESET}"

echo -e "\n${BOLD}${CYAN}[*] Phase 1: Provisioning testing environment & GKE Cluster (Takes 3-5 mins)...${RESET}"
gcloud container clusters create scaling-demo --num-nodes=3 --enable-vertical-pod-autoscaling --quiet

echo -e "\n${BOLD}${YELLOW}[*] Phase 2: Deploying PHP Apache Application...${RESET}"
cat << EOF > php-apache.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  selector:
    matchLabels:
      run: php-apache
  replicas: 3
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
      - name: php-apache
        image: k8s.gcr.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  labels:
    run: php-apache
spec:
  ports:
  - port: 80
  selector:
    run: php-apache
EOF
kubectl apply -f php-apache.yaml
echo "${CYAN}Waiting for PHP Apache deployment to initialize...${RESET}"
kubectl wait --for=condition=Available deployment/php-apache --timeout=120s

echo -e "\n${BOLD}${MAGENTA}[*] Phase 3: Configuring Horizontal Pod Autoscaler (HPA)...${RESET}"
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
sleep 5 # Brief pause for HPA registration

echo -e "\n${BOLD}${YELLOW}[*] Phase 4: Deploying Hello-Server & Configuring VPA...${RESET}"
kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
kubectl set resources deployment hello-server --requests=cpu=450m

cat << EOF > hello-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: hello-server-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       hello-server
  updatePolicy:
    updateMode: "Off"
EOF
kubectl apply -f hello-vpa.yaml
sleep 5 # Allow VPA to register before updating to Auto

echo "${CYAN}Updating VPA to Auto Mode...${RESET}"
sed -i 's/Off/Auto/g' hello-vpa.yaml
kubectl apply -f hello-vpa.yaml
kubectl scale deployment hello-server --replicas=2

echo -e "\n${BOLD}${CYAN}[*] Phase 5: Configuring Cluster Autoscaler...${RESET}"
gcloud beta container clusters update scaling-demo --enable-autoscaling --min-nodes 1 --max-nodes 5 --quiet
gcloud beta container clusters update scaling-demo --autoscaling-profile optimize-utilization --quiet

echo -e "\n${BOLD}${MAGENTA}[*] Phase 6: Creating Pod Disruption Budgets (PDBs)...${RESET}"
kubectl create poddisruptionbudget kube-dns-pdb --namespace=kube-system --selector k8s-app=kube-dns --max-unavailable 1
kubectl create poddisruptionbudget prometheus-pdb --namespace=kube-system --selector k8s-app=prometheus-to-sd --max-unavailable 1
kubectl create poddisruptionbudget kube-proxy-pdb --namespace=kube-system --selector component=kube-proxy --max-unavailable 1
kubectl create poddisruptionbudget metrics-agent-pdb --namespace=kube-system --selector k8s-app=gke-metrics-agent --max-unavailable 1
kubectl create poddisruptionbudget metrics-server-pdb --namespace=kube-system --selector k8s-app=metrics-server --max-unavailable 1
kubectl create poddisruptionbudget fluentd-pdb --namespace=kube-system --selector k8s-app=fluentd-gke --max-unavailable 1
kubectl create poddisruptionbudget backend-pdb --namespace=kube-system --selector k8s-app=glbc --max-unavailable 1
kubectl create poddisruptionbudget kube-dns-autoscaler-pdb --namespace=kube-system --selector k8s-app=kube-dns-autoscaler --max-unavailable 1
kubectl create poddisruptionbudget stackdriver-pdb --namespace=kube-system --selector app=stackdriver-metadata-agent --max-unavailable 1
kubectl create poddisruptionbudget event-pdb --namespace=kube-system --selector k8s-app=event-exporter --max-unavailable 1

echo -e "\n${BOLD}${YELLOW}[*] Phase 7: Enabling Node Auto Provisioning (NAP)...${RESET}"
gcloud container clusters update scaling-demo \
    --enable-autoprovisioning \
    --min-cpu 1 \
    --min-memory 2 \
    --max-cpu 45 \
    --max-memory 160 \
    --quiet

echo -e "\n${BOLD}${CYAN}[*] Phase 8: Deploying Pause Pods (Overprovisioning)...${RESET}"
cat << EOF > pause-pod.yaml
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: overprovisioning
value: -1
globalDefault: false
description: "Priority class used by overprovisioning."
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: overprovisioning
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      run: overprovisioning
  template:
    metadata:
      labels:
        run: overprovisioning
    spec:
      priorityClassName: overprovisioning
      containers:
      - name: reserve-resources
        image: k8s.gcr.io/pause
        resources:
          requests:
            cpu: 1
            memory: 4Gi
EOF
kubectl apply -f pause-pod.yaml

echo -e "\n${BOLD}${GREEN}====================================================================${RESET}"
echo "${BOLD}${GREEN}>>> ALL TASKS COMPLETE! YOU CAN NOW CLICK 'CHECK MY PROGRESS' <<< ${RESET}"
echo "${BOLD}${GREEN}====================================================================${RESET}"
