#!/bin/bash
set -e

AWS_PROFILE="${AWS_PROFILE:-wiz}"
S3_BUCKET="wiz-tech-exercise-terraform-state-180294187104"
DYNAMODB_TABLE="wiz-tech-exercise-terraform-locks"

echo "=============================================="
echo "Clear Terraform State Corruption"
echo "=============================================="
echo ""
echo "This script fixes checksum mismatches between S3 and DynamoDB."
echo ""

clear_state() {
    local state_key=$1
    local state_name=$2
    
    echo "Processing $state_name..."
    
    # Remove DynamoDB checksum entry
    echo "  Removing DynamoDB checksum..."
    aws dynamodb delete-item \
      --table-name $DYNAMODB_TABLE \
      --key "{\"LockID\":{\"S\":\"$S3_BUCKET/$state_key-md5\"}}" \
      2>/dev/null || echo "  (no checksum found)"
    
    # Check if S3 state exists and is valid
    if aws s3 ls s3://$S3_BUCKET/$state_key 2>/dev/null; then
        STATE_SIZE=$(aws s3api head-object \
          --bucket $S3_BUCKET \
          --key $state_key \
          --query ContentLength \
          --output text 2>/dev/null || echo "0")
        
        if [ "$STATE_SIZE" -lt "500" ]; then
            echo "  State file is corrupted ($STATE_SIZE bytes). Removing..."
            aws s3 rm s3://$S3_BUCKET/$state_key
            echo "  ✅ Removed corrupted state"
        else
            echo "  ✅ State file is valid ($STATE_SIZE bytes)"
        fi
    else
        echo "  ℹ️  No state file exists (will be created on first apply)"
    fi
    
    echo ""
}

echo "Clearing state corruption for all modules..."
echo ""

clear_state "dev/eks/terraform.tfstate" "EKS"
clear_state "dev/ec2/terraform.tfstate" "EC2"
clear_state "cicd/github-oidc/terraform.tfstate" "GitHub OIDC"

echo "=============================================="
echo "✅ State Cleanup Complete!"
echo "=============================================="
echo ""
echo "You can now run:"
echo "  cd iac/envs/dev/eks && terraform init -reconfigure"
echo "  cd iac/envs/dev/ec2 && terraform init -reconfigure"
echo ""

