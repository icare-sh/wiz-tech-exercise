#!/bin/bash
set -e

AWS_PROFILE="${AWS_PROFILE:-wiz}"
AWS_REGION="${AWS_REGION:-us-east-1}"
S3_BUCKET="wiz-tech-exercise-terraform-state-180294187104"

echo "=============================================="
echo "Terraform State Verification"
echo "=============================================="
echo ""

verify_state() {
    local state_key=$1
    local state_name=$2
    
    echo "Checking $state_name state..."
    
    if aws s3 ls s3://$S3_BUCKET/$state_key 2>/dev/null; then
        STATE_SIZE=$(aws s3 ls s3://$S3_BUCKET/$state_key --summarize | grep "Total Size" | awk '{print $3}')
        
        if [ -z "$STATE_SIZE" ]; then
            STATE_SIZE=0
        fi
        
        if [ "$STATE_SIZE" -lt "500" ]; then
            echo "  ⚠️  State exists but is suspiciously small: $STATE_SIZE bytes"
            echo "  📥 Downloading to inspect..."
            aws s3 cp s3://$S3_BUCKET/$state_key /tmp/state_check.json
            RESOURCE_COUNT=$(grep -o '"resources"' /tmp/state_check.json | wc -l)
            
            if [ "$RESOURCE_COUNT" -eq "0" ]; then
                echo "  ❌ State contains NO resources (empty state)"
            else
                echo "  ✅ State file is valid"
            fi
            rm -f /tmp/state_check.json
        else
            echo "  ✅ State exists: $STATE_SIZE bytes"
        fi
    else
        echo "  ❌ State does NOT exist in S3"
    fi
    
    echo ""
}

echo "Verifying all Terraform states in S3..."
echo ""

verify_state "cicd/github-oidc/terraform.tfstate" "GitHub OIDC"
verify_state "dev/eks/terraform.tfstate" "EKS"
verify_state "dev/ec2/terraform.tfstate" "EC2"

echo "=============================================="
echo "Local State Check"
echo "=============================================="
echo ""

check_local_state() {
    local dir=$1
    local name=$2
    
    echo "Checking $name local state..."
    
    if [ -f "$dir/terraform.tfstate" ]; then
        echo "  ⚠️  WARNING: Local state file exists!"
        echo "  This should NOT exist when using remote S3 backend."
        echo "  File: $dir/terraform.tfstate"
    else
        echo "  ✅ No local state (correct - using S3 backend)"
    fi
    
    echo ""
}

check_local_state "iac/github-oidc" "GitHub OIDC"
check_local_state "iac/envs/dev/eks" "EKS"
check_local_state "iac/envs/dev/ec2" "EC2"

echo "=============================================="
echo "Summary"
echo "=============================================="
echo ""
echo "To pull latest state from S3:"
echo "  cd iac/envs/dev/eks && terraform init -reconfigure"
echo "  cd iac/envs/dev/ec2 && terraform init -reconfigure"
echo ""
echo "To view state contents:"
echo "  terraform -chdir=iac/envs/dev/eks state list"
echo "  terraform -chdir=iac/envs/dev/ec2 state list"
echo ""

