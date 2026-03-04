#!/bin/bash
###############################################################################
# DEMO STAGE 2: Application Running + Kubernetes (~3 min)
#
# GOAL   : Prove everything works + show intentional weaknesses
# FORMAT : 100% live terminal + browser
#
# TALKING POINTS:
# - Functional 2-tier app (Go + MongoDB)
# - Intentional weaknesses: cluster-admin, AdministratorAccess
# - wizexercise.txt present in the container
# - Data actually stored in MongoDB
###############################################################################
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pause() {
    echo ""
    echo -e "${YELLOW}[Press Enter to continue...]${NC}"
    read -r
}

header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_cmd() {
    echo -e "\n${GREEN}\$ $1${NC}"
    eval "$1"
}

###############################################################################
header "2.1 - KUBERNETES CLUSTER STATE"
###############################################################################
echo -e "${BOLD}EKS cluster overview:${NC}"

run_cmd "kubectl get nodes -o wide"
pause

echo -e "${BOLD}All pods (app + system + security):${NC}"
run_cmd "kubectl get pods -A"
pause

###############################################################################
header "2.2 - WEB APPLICATION + INGRESS"
###############################################################################
echo -e "${BOLD}Application pod:${NC}"
run_cmd "kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o wide"

echo ""
echo -e "${BOLD}Service and Ingress (exposed via ALB):${NC}"
run_cmd "kubectl get svc,ingress"

APP_URL=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -n "$APP_URL" ]; then
    echo ""
    echo -e "${GREEN}-> Open in browser: http://${APP_URL}${NC}"
    echo -e "${GREEN}-> Create an account, log in, add a todo${NC}"
fi
pause

###############################################################################
header "2.3 - MONGODB_URI via Kubernetes environment variable"
###############################################################################
echo -e "${BOLD}MongoDB access is configured via a K8s Secret -> env var:${NC}"

POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o jsonpath='{.items[0].metadata.name}')

run_cmd "kubectl get secret -l app.kubernetes.io/name=wiz-exercise-app"
echo ""
echo -e "${BOLD}Environment variables injected into the pod:${NC}"
run_cmd "kubectl exec $POD_NAME -- env | grep -E 'MONGODB_URI|SECRET_KEY|ENVIRONMENT' | sed 's/\(MONGODB_URI=mongodb:\/\/[^:]*:\)[^@]*/\1*****/'"
pause

###############################################################################
header "2.4 - wizexercise.txt FILE IN THE CONTAINER"
###############################################################################
echo -e "${BOLD}Verifying wizexercise.txt (required by the exercise):${NC}"
echo ""
echo "The file is added via the Dockerfile: COPY wizexercise.txt ."
echo ""

run_cmd "kubectl exec $POD_NAME -- cat /app/wizexercise.txt"
echo ""
echo -e "${GREEN}-> The file contains my name and is present in the image${NC}"
pause

###############################################################################
header "2.5 - WEAKNESS: CLUSTER-ADMIN on the application pod"
###############################################################################
echo -e "${RED}${BOLD}Intentional vulnerability: the pod has cluster-admin privileges${NC}"
echo ""

echo -e "${BOLD}ClusterRoleBinding:${NC}"
run_cmd "kubectl get clusterrolebinding wiz-app-wiz-exercise-app-admin -o yaml | grep -A5 'roleRef:'"

echo ""
echo -e "${BOLD}Proof: the pod can do anything in the cluster${NC}"
run_cmd "kubectl auth can-i --list --as=system:serviceaccount:default:wiz-securelabs-app-sa | head -10"

echo ""
echo -e "${RED}Impact: If the pod is compromised, the attacker controls the entire K8s cluster${NC}"
echo -e "${RED}  -> Read secrets from all namespaces${NC}"
echo -e "${RED}  -> Deploy malicious pods${NC}"
echo -e "${RED}  -> Pivot to AWS via IRSA${NC}"
pause

###############################################################################
header "2.6 - EC2 MONGODB: Prove data + show weaknesses"
###############################################################################

MONGO_IP=$(cd /home/sabir/wiz-v2/wiz-tech-exercise/iac/envs/dev/ec2 && terraform output -raw mongo_public_ip 2>/dev/null || echo "")

echo -e "${BOLD}SSH into the MongoDB VM (port 22 open to the world):${NC}"
echo ""
if [ -n "$MONGO_IP" ]; then
    echo -e "${GREEN}\$ ssh ubuntu@${MONGO_IP}${NC}"
    echo ""
    echo "Once connected, run these commands:"
    echo ""
    echo -e "${CYAN}# 1. Prove data is in MongoDB${NC}"
    echo '  mongo admin -u admin -p <password> --eval "db.getSiblingDB('"'"'admin'"'"').todos.find().pretty()"'
    echo ""
    echo -e "${CYAN}# 2. Show MongoDB version (4.4 = outdated)${NC}"
    echo "  mongod --version"
    echo ""
    echo -e "${CYAN}# 3. Show Ubuntu version (20.04 = outdated)${NC}"
    echo "  lsb_release -a"
    echo ""
    echo -e "${CYAN}# 4. WEAKNESS: Show the IAM role with AdministratorAccess${NC}"
    echo "  curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/"
    echo "  # Then:"
    echo '  aws sts get-caller-identity'
    echo '  aws iam list-attached-role-policies --role-name wiz-datastore-mongo-mongo-role'
    echo ""
    echo -e "${RED}Impact: The VM has admin rights over the entire AWS account!${NC}"
    echo -e "${RED}  -> Create/delete VMs, read all secrets, etc.${NC}"
else
    echo "MongoDB IP not found. Use: cd iac/envs/dev/ec2 && terraform output mongo_public_ip"
fi
pause

echo -e "${GREEN}-> [Stage 2 done] Let's move to cloud security...${NC}"
