#!/bin/bash
###############################################################################
# DEMO STAGE 3: Cloud Native Security (~4 min)
#
# GOAL   : Show the value of implemented security controls
# FORMAT : Terminal + AWS Console + emails
#
# TALKING POINTS:
# - Audit logging: CloudTrail (who did what, when)
# - Detective: Config (misconfigs), GuardDuty (threats), Inspector (CVEs)
# - Preventive: Password Policy, WAF, fail2ban
# - Runtime: Falco (suspicious behavior in K8s)
# - Alerting: SNS + EventBridge -> real-time email
###############################################################################
set -euo pipefail

AWS_REGION="us-east-1"
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
header "3.1 - AUDIT: CloudTrail (control plane logging)"
###############################################################################
echo -e "${BOLD}CloudTrail records EVERY API action in the AWS account:${NC}"
echo ""

run_cmd "aws cloudtrail describe-trails --region $AWS_REGION --query 'trailList[].{Name:Name,S3Bucket:S3BucketName,IsMultiRegion:IsMultiRegionTrail,LogValidation:LogFileValidationEnabled}' --output table"

echo ""
echo "Recent events (last 5):"
run_cmd "aws cloudtrail lookup-events --region $AWS_REGION --max-results 5 --query 'Events[].{Time:EventTime,User:Username,Action:EventName,Source:EventSource}' --output table"

echo ""
echo -e "${GREEN}-> Also show in AWS Console: CloudTrail > Event history${NC}"
echo -e "${GREEN}   Filter by 'Event source = ec2.amazonaws.com' to see EC2 actions${NC}"
pause

###############################################################################
header "3.2 - DETECTIVE: AWS Config (misconfigurations detected)"
###############################################################################
echo -e "${BOLD}AWS Config continuously monitors resource compliance:${NC}"
echo ""
echo "Compliance rules:"
run_cmd "aws configservice describe-compliance-by-config-rule --region $AWS_REGION --query 'ComplianceByConfigRules[].{Rule:ConfigRuleName,Status:Compliance.ComplianceType}' --output table"

echo ""
echo -e "${RED}NON-COMPLIANT resources:${NC}"

echo ""
echo -e "${BOLD}[restricted-ssh] Security Groups with open SSH:${NC}"
run_cmd "aws configservice get-compliance-details-by-config-rule --config-rule-name restricted-ssh --compliance-types NON_COMPLIANT --region $AWS_REGION --query 'EvaluationResults[].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,Status:ComplianceType}' --output table 2>/dev/null || echo '(not yet evaluated or no results)'"

echo ""
echo -e "${BOLD}[s3-bucket-public-read-prohibited] Public S3 buckets:${NC}"
run_cmd "aws configservice get-compliance-details-by-config-rule --config-rule-name s3-bucket-public-read-prohibited --compliance-types NON_COMPLIANT --region $AWS_REGION --query 'EvaluationResults[].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,Status:ComplianceType}' --output table 2>/dev/null || echo '(not yet evaluated or no results)'"

echo ""
echo -e "${RED}Both weaknesses are INTENTIONAL for the exercise:${NC}"
echo "  - SSH 0.0.0.0/0 on the MongoDB security group"
echo "  - S3 backup bucket with public-read"
echo ""
echo -e "${GREEN}-> Show in Console: AWS Config > Rules > see details${NC}"
pause

###############################################################################
header "3.3 - DETECTIVE: GuardDuty (threats detected)"
###############################################################################
echo -e "${BOLD}GuardDuty analyzes VPC/DNS/CloudTrail logs to detect threats:${NC}"
echo ""

DETECTOR_ID=$(aws guardduty list-detectors --region $AWS_REGION --query "DetectorIds[0]" --output text)

echo "Recent findings:"
run_cmd "aws guardduty list-findings --detector-id $DETECTOR_ID --region $AWS_REGION --finding-criteria '{\"Criterion\":{\"severity\":{\"Gte\":7}}}' --max-results 5 --query 'FindingIds' --output json"

FINDINGS=$(aws guardduty list-findings --detector-id "$DETECTOR_ID" --region $AWS_REGION --max-results 3 --query 'FindingIds' --output json)
FINDING_IDS=$(echo "$FINDINGS" | tr -d '[]" \n')

if [ -n "$FINDING_IDS" ] && [ "$FINDING_IDS" != "" ]; then
    echo ""
    echo "Finding details:"
    # Get first finding only for display
    FIRST_ID=$(echo "$FINDINGS" | python3 -c "import sys,json; ids=json.load(sys.stdin); print(ids[0] if ids else '')" 2>/dev/null || echo "")
    if [ -n "$FIRST_ID" ]; then
        run_cmd "aws guardduty get-findings --detector-id $DETECTOR_ID --finding-ids $FIRST_ID --region $AWS_REGION --query 'Findings[].{Type:Type,Severity:Severity,Title:Title,Description:Description}' --output table"
    fi
fi

echo ""
echo -e "${GREEN}-> Show the GuardDuty email received (email tab prepared before the demo)${NC}"
echo -e "${GREEN}-> Show in Console: GuardDuty > Findings${NC}"
pause

###############################################################################
header "3.4 - DETECTIVE: AWS Inspector (CVE scanning on EC2)"
###############################################################################
echo -e "${BOLD}Inspector automatically scans CVEs on the MongoDB EC2 instance:${NC}"
echo ""

run_cmd "aws inspector2 list-findings --region $AWS_REGION --filter-criteria '{\"findingStatus\":[{\"comparison\":\"EQUALS\",\"value\":\"ACTIVE\"}]}' --max-results 5 --query 'findings[].{Title:title,Severity:severity,Resource:resources[0].id}' --output table 2>/dev/null || echo 'Inspector scanning in progress or no findings'"

echo ""
echo -e "${GREEN}-> Show in Console: Inspector > Findings > filter by EC2${NC}"
echo -e "${GREEN}   Show CVEs related to outdated Ubuntu 20.04${NC}"
pause

###############################################################################
header "3.5 - PREVENTIVE: IAM Password Policy"
###############################################################################
echo -e "${BOLD}IAM password policy (preventive control):${NC}"
echo ""
run_cmd "aws iam get-account-password-policy --query 'PasswordPolicy.{MinLength:MinimumPasswordLength,RequireLowercase:RequireLowercaseCharacters,RequireUppercase:RequireUppercaseCharacters,RequireNumbers:RequireNumbers,RequireSymbols:RequireSymbols}' --output table"

echo ""
echo -e "${GREEN}Prevents creation of weak passwords for IAM users${NC}"
pause

###############################################################################
header "3.6 - PREVENTIVE: WAF (Web Application Firewall)"
###############################################################################
echo -e "${BOLD}WAF protects the ALB against web attacks:${NC}"
echo ""

WAF_ACL_ARN=$(cd /home/sabir/wiz-v2/wiz-tech-exercise/iac/envs/dev/eks && terraform output -raw waf_acl_arn 2>/dev/null || echo "")
if [ -n "$WAF_ACL_ARN" ]; then
    WAF_ACL_ID=$(echo "$WAF_ACL_ARN" | grep -oP '[^/]+$')
    WAF_ACL_NAME=$(echo "$WAF_ACL_ARN" | grep -oP '(?<=webacl/)[^/]+')
    run_cmd "aws wafv2 get-web-acl --name $WAF_ACL_NAME --scope REGIONAL --id $WAF_ACL_ID --region $AWS_REGION --query 'WebACL.{Name:Name,Rules:Rules[].Name}' --output table 2>/dev/null || echo 'WAF details not available'"
fi

echo ""
echo -e "${GREEN}WAF is attached to the ALB via the Kubernetes Ingress annotation${NC}"
pause

###############################################################################
header "3.7 - RUNTIME: Falco (Kubernetes security)"
###############################################################################
echo -e "${BOLD}Falco monitors suspicious behavior in K8s pods:${NC}"
echo ""

echo "Falco pods:"
run_cmd "kubectl get pods -n falco"

echo ""
echo -e "${BOLD}Recent Falco logs (alerts):${NC}"
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$FALCO_POD" ]; then
    run_cmd "kubectl logs $FALCO_POD -n falco --tail=10 | grep -i 'Warning\|Notice\|Error' | tail -5 || echo 'No recent alerts in logs'"
fi

echo ""
echo -e "${BOLD}Live trigger: exec into the pod = Falco alert${NC}"
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    echo -e "${RED}Running a suspicious command inside the pod:${NC}"
    run_cmd "kubectl exec $POD_NAME -- cat /etc/shadow 2>/dev/null || true"
    echo ""
    echo -e "${GREEN}-> Falco detects: 'Terminal shell in container' / 'Read sensitive file'${NC}"
    echo -e "${GREEN}-> A Falco email is sent via SES (show the prepared email)${NC}"
fi
pause

###############################################################################
header "3.8 - BONUS: Fail2ban (SSH brute-force protection)"
###############################################################################
echo -e "${BOLD}Fail2ban is installed on the MongoDB EC2 to block SSH brute-force attacks:${NC}"
echo ""

MONGO_IP=$(cd /home/sabir/wiz-v2/wiz-tech-exercise/iac/envs/dev/ec2 && terraform output -raw mongo_public_ip 2>/dev/null || echo "")

if [ -n "$MONGO_IP" ]; then
    echo "Config: 5 failed attempts = banned for 5 minutes"
    echo ""
    echo -e "${RED}Live demo: we'll attempt SSH connections with a wrong password:${NC}"
    echo ""
    echo "Run in ANOTHER terminal:"
    echo -e "${CYAN}"
    echo "  for i in 1 2 3 4 5 6; do"
    echo "    echo \"Attempt \$i...\""
    echo "    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o PasswordAuthentication=yes fakeuser@${MONGO_IP} 2>&1 || true"
    echo "  done"
    echo -e "${NC}"
    echo ""
    echo "Then verify on the MongoDB server (via your existing SSH session):"
    echo -e "${CYAN}"
    echo "  sudo fail2ban-client status sshd"
    echo -e "${NC}"
    echo ""
    echo "You'll see your IP in the 'Banned IP list'"
else
    echo "MongoDB IP not found."
fi
pause

###############################################################################
header "SECURITY SUMMARY"
###############################################################################
echo ""
echo -e "${BOLD}Implemented controls:${NC}"
echo ""
echo "  AUDIT          CloudTrail          Logging of all API actions"
echo "  DETECTIVE      AWS Config          Detects open SSH + public S3"
echo "  DETECTIVE      GuardDuty           Detects threats (brute-force, crypto...)"
echo "  DETECTIVE      Inspector           CVE scanning on EC2 (outdated Ubuntu)"
echo "  DETECTIVE      Falco               K8s runtime (suspicious exec, sensitive files)"
echo "  PREVENTIVE     Password Policy     Strong passwords enforced"
echo "  PREVENTIVE     WAF                 Web protection (SQLi, XSS, rate limit)"
echo "  PREVENTIVE     Fail2ban            SSH brute-force ban"
echo "  PIPELINE       Trivy               IaC + secrets + vuln scanning before deploy"
echo ""
echo -e "${BOLD}Intentional weaknesses (required by the exercise):${NC}"
echo ""
echo -e "  ${RED}SSH open 0.0.0.0/0${NC}         -> Detected by Config + GuardDuty"
echo -e "  ${RED}S3 backup public-read${NC}      -> Detected by Config"
echo -e "  ${RED}EC2 AdministratorAccess${NC}    -> Overly permissive permissions"
echo -e "  ${RED}Pod cluster-admin${NC}          -> K8s privilege escalation"
echo -e "  ${RED}Ubuntu 20.04 + Mongo 4.4${NC}   -> CVEs detected by Inspector"
echo ""
echo -e "${GREEN}=== END OF DEMO ===${NC}"
