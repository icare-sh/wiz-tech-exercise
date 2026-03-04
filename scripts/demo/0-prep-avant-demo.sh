#!/bin/bash
###############################################################################
# PRE-DEMO PREPARATION - Run 24-48h before the presentation
# This script prepares alerts and verifies everything is ready
###############################################################################
set -euo pipefail

AWS_REGION="us-east-1"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }
ok()     { echo -e "${GREEN}[OK]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!!]${NC} $1"; }
fail()   { echo -e "${RED}[KO]${NC} $1"; }

###############################################################################
header "STEP 1: Confirm SNS subscription (GuardDuty email alerts)"
###############################################################################
echo "You should have received an email 'AWS Notification - Subscription Confirmation'"
echo "from 'no-reply@sns.amazonaws.com'."
echo ""
echo "-> Go to your inbox and click 'Confirm subscription'"
echo ""

# Check subscription status
SNS_TOPIC_ARN=$(aws sns list-topics --region "$AWS_REGION" --query "Topics[?contains(TopicArn,'security-alerts')].TopicArn" --output text)
if [ -n "$SNS_TOPIC_ARN" ]; then
    SUBS=$(aws sns list-subscriptions-by-topic --topic-arn "$SNS_TOPIC_ARN" --region "$AWS_REGION" --query "Subscriptions[0].SubscriptionArn" --output text)
    if [[ "$SUBS" == "PendingConfirmation" ]]; then
        fail "SNS Subscription pending confirmation! Go confirm in your inbox."
    elif [[ "$SUBS" == "None" ]] || [[ -z "$SUBS" ]]; then
        fail "No SNS subscription found."
    else
        ok "SNS Subscription confirmed: $SUBS"
    fi
else
    fail "SNS Topic 'security-alerts' not found."
fi

###############################################################################
header "STEP 2: Generate GuardDuty sample findings"
###############################################################################
echo "Generating GuardDuty findings to have email alerts to show during the demo."
echo ""

DETECTOR_ID=$(aws guardduty list-detectors --region "$AWS_REGION" --query "DetectorIds[0]" --output text)

if [ -n "$DETECTOR_ID" ] && [ "$DETECTOR_ID" != "None" ]; then
    ok "GuardDuty Detector ID: $DETECTOR_ID"

    echo "Generating sample findings..."
    aws guardduty create-sample-findings \
        --detector-id "$DETECTOR_ID" \
        --region "$AWS_REGION" \
        --finding-types \
            "UnauthorizedAccess:EC2/SSHBruteForce" \
            "Recon:EC2/PortProbeUnprotectedPort" \
            "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" \
            "CryptoCurrency:EC2/BitcoinTool.B!DNS"

    ok "Sample findings generated. You should receive emails within 5-15 minutes."
    echo ""
    echo "-> Check your inbox for GuardDuty alerts (subject: 'AWS Notification Message')"
    echo "-> Keep these emails open in a tab for the demo"
else
    fail "No GuardDuty detector found. Deploy the security layer first."
fi

###############################################################################
header "STEP 3: Verify SES (Falco email alerts)"
###############################################################################
echo "Checking that SES identities are verified..."

SES_IDENTITIES=$(aws ses list-identities --region "$AWS_REGION" --query "Identities" --output text)
if [ -n "$SES_IDENTITIES" ]; then
    for identity in $SES_IDENTITIES; do
        STATUS=$(aws ses get-identity-verification-attributes --identities "$identity" --region "$AWS_REGION" \
            --query "VerificationAttributes.\"$identity\".VerificationStatus" --output text)
        if [ "$STATUS" == "Success" ]; then
            ok "SES Identity verified: $identity"
        else
            warn "SES Identity NOT verified: $identity (status: $STATUS)"
            echo "   -> Go to your inbox and click the SES verification link"
        fi
    done
else
    warn "No SES identities found."
fi

###############################################################################
header "STEP 4: Trigger a Falco alert (to get an email)"
###############################################################################
echo "Exec-ing into the app pod to trigger Falco..."

POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    ok "Pod found: $POD_NAME"
    echo "Running suspicious commands to trigger Falco..."

    # Trigger: "Terminal shell in container"
    kubectl exec "$POD_NAME" -- cat /etc/shadow 2>/dev/null || true

    # Trigger: "Read sensitive file"
    kubectl exec "$POD_NAME" -- cat /etc/passwd 2>/dev/null || true

    ok "Commands executed. Falco should send an email within a few minutes."
    echo "-> Check your inbox for a Falco email (subject contains 'Falco')"
else
    warn "App pod not found. Check that the app is deployed: kubectl get pods"
fi

###############################################################################
header "STEP 5: Verify everything is up"
###############################################################################

echo "--- EKS Cluster ---"
kubectl cluster-info 2>/dev/null && ok "EKS Cluster accessible" || fail "EKS Cluster unreachable"

echo ""
echo "--- Pods ---"
kubectl get pods -A --no-headers 2>/dev/null | head -20

echo ""
echo "--- App Ingress / URL ---"
APP_URL=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "not-found")
if [ "$APP_URL" != "not-found" ] && [ -n "$APP_URL" ]; then
    ok "App accessible at: http://$APP_URL"
else
    warn "Ingress URL not found. Check: kubectl get ingress"
fi

echo ""
echo "--- EC2 MongoDB ---"
MONGO_IP=$(cd /home/sabir/wiz-v2/wiz-tech-exercise/iac/envs/dev/ec2 && terraform output -raw mongo_public_ip 2>/dev/null || echo "not-found")
if [ "$MONGO_IP" != "not-found" ]; then
    ok "MongoDB EC2 public IP: $MONGO_IP"
    echo "   Test SSH: ssh -i ~/.ssh/mongo_key ubuntu@$MONGO_IP"
else
    warn "MongoDB IP not found via Terraform."
fi

###############################################################################
header "FINAL CHECKLIST"
###############################################################################
echo "Before the demo, make sure you have:"
echo "  [ ] SNS email confirmed + GuardDuty emails received"
echo "  [ ] Falco email received"
echo "  [ ] SES identities verified"
echo "  [ ] App accessible in the browser (create a test todo)"
echo "  [ ] SSH key for MongoDB EC2 available"
echo "  [ ] kubectl configured and working"
echo "  [ ] Tabs open: AWS Console (GuardDuty, Config, CloudTrail, Inspector)"
echo "  [ ] Terminal ready with demo scripts"
echo ""
echo "Next step: Run the demo scripts (1, 2, 3) on demo day"
