#!/bin/bash
###############################################################################
# DEMO STAGE 1: DevSecOps Pipeline (~3 min)
#
# GOAL   : Show CI/CD automation and pipeline security
# FORMAT : Mix of slides (GitHub UI) + quick terminal
#
# TALKING POINTS:
# - "Zero static credentials" -> OIDC
# - "Security shift-left" -> Trivy in CI
# - "Infrastructure as Code" -> Terraform + Ansible
# - "One tag = full deploy" -> CD pipeline
###############################################################################
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
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

###############################################################################
header "1.1 - AUTHENTICATION: GitHub OIDC -> AWS (zero static secrets)"
###############################################################################
echo ""
echo -e "${BOLD}How GitHub Actions authenticates to AWS without any access key:${NC}"
echo ""
echo "  GitHub Actions  --OIDC token-->  AWS STS  --AssumeRole-->  IAM Role"
echo ""
echo "  - No access key/secret stored in GitHub"
echo "  - The IAM role only trusts the repo icare-sh/wiz-tech-exercise"
echo "  - Temporary token per run (expires after the job)"
echo ""
echo -e "${GREEN}-> Show in GitHub: Settings > Secrets > no AWS key present${NC}"
echo -e "${GREEN}-> Show the OIDC role in AWS IAM Console${NC}"
pause

###############################################################################
header "1.2 - CI PIPELINE: Security Shift-Left (Trivy)"
###############################################################################
echo ""
echo -e "${BOLD}On every Pull Request, 4 automated scans run:${NC}"
echo ""
echo "  1. Trivy FS Scan       -> OS/library vulnerabilities"
echo "  2. Trivy Config Scan   -> IaC misconfigurations (Terraform)"
echo "  3. Trivy Secret Scan   -> Leaked credentials in code"
echo "  4. Terraform Validate  -> Syntax + module validation"
echo ""
echo -e "${GREEN}-> Show in GitHub: Actions > latest run of 'Security & Quality Check'${NC}"
echo -e "${GREEN}-> Show the Trivy reports (artifacts)${NC}"
pause

###############################################################################
header "1.3 - CD PIPELINE: One tag = full deployment"
###############################################################################
echo ""
echo -e "${BOLD}Automated deployment flow (git tag -> production):${NC}"
echo ""
echo "  git push tag v1.0.0"
echo "       |"
echo "       v"
echo "  Job 1: Deploy Infrastructure"
echo "    -> Security Layer (CloudTrail, GuardDuty, Config)"
echo "    -> EKS Cluster + Falco + WAF + ALB Controller"
echo "    -> EC2 MongoDB + ECR + S3 + SSM Parameters"
echo "       |"
echo "       v"
echo "  Job 2: Configure MongoDB (Ansible)"
echo "    -> Install MongoDB 4.4 + create admin user"
echo "    -> Setup backup cron + fail2ban + SSM Agent"
echo "       |"
echo "       v"
echo "  Job 3: Build & Deploy App"
echo "    -> Docker build + push to ECR"
echo "    -> Helm deploy to EKS"
echo ""
echo -e "${GREEN}-> Show in GitHub: Actions > latest run of 'Production Release'${NC}"
echo -e "${GREEN}-> Show the 3 jobs and their dependencies${NC}"
pause

###############################################################################
header "1.4 - INFRA AS CODE: Terraform layers"
###############################################################################
echo ""
echo -e "${BOLD}Terraform architecture in 3 isolated layers:${NC}"
echo ""
echo "  iac/envs/dev/"
echo "  ├── security/   -> CloudTrail, GuardDuty, Config, Inspector, Password Policy"
echo "  ├── eks/         -> VPC, EKS, Falco, WAF, ALB Controller"
echo "  └── ec2/         -> MongoDB VM, ECR, S3 backups, SSM Parameters"
echo ""
echo "  Each layer has its own S3 state + DynamoDB lock"
echo "  Remote state = team collaboration + no data loss"
echo ""
echo -e "${BOLD}Secrets management:${NC}"
echo "  GitHub Secrets -> TF_VAR -> aws_ssm_parameter (SecureString/KMS)"
echo "  -> Never any password hardcoded in the codebase"
echo ""
echo -e "${GREEN}-> [Stage 1 done] Let's move to the live application...${NC}"
pause
