#!/bin/bash
set -e

echo "=============================================="
echo "Wiz Tech Exercise - Clean Slate Deployment"
echo "=============================================="
echo ""

AWS_PROFILE="${AWS_PROFILE:-wiz}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Using AWS Profile: $AWS_PROFILE"
echo "Using AWS Region: $AWS_REGION"
echo ""

cd "$(dirname "$0")/.."

echo "[Step 1/7] Configuring Terraform backend to use S3 remote state..."

# S'assurer que les fichiers backend.tf existent
if [ ! -f "iac/envs/dev/eks/backend.tf" ]; then
    echo "Creating backend.tf for EKS..."
    cp iac/envs/dev/eks/backend.tf.example iac/envs/dev/eks/backend.tf
fi

if [ ! -f "iac/envs/dev/ec2/backend.tf" ]; then
    echo "Creating backend.tf for EC2..."
    cp iac/envs/dev/ec2/backend.tf.example iac/envs/dev/ec2/backend.tf
fi

echo ""
echo "[Step 2/7] Pulling remote state from S3 and destroying EKS..."
cd iac/envs/dev/eks

# Supprimer le state local s'il existe
rm -f terraform.tfstate terraform.tfstate.backup

# Initialiser avec le backend S3 (récupère le state distant)
terraform init -reconfigure

# Vérifier ce qu'il y a dans le state
echo "Resources in EKS state:"
terraform state list || echo "No resources in state"

echo ""
read -p "Press Enter to destroy EKS resources..."

terraform destroy -auto-approve || echo "EKS already destroyed or doesn't exist"
cd -

echo ""
echo "[Step 3/7] Destroying EC2 + MongoDB..."
cd iac/envs/dev/ec2

# Supprimer le state local s'il existe
rm -f terraform.tfstate terraform.tfstate.backup

# Initialiser avec le backend S3
terraform init -reconfigure

# Vérifier ce qu'il y a dans le state
echo "Resources in EC2 state:"
terraform state list || echo "No resources in state"

echo ""
read -p "Press Enter to destroy EC2 resources..."

terraform destroy -auto-approve || echo "EC2 already destroyed or doesn't exist"
cd -

echo ""
echo "[Step 4/7] Cleaning up orphaned AWS resources..."

# Delete CloudWatch log groups
echo "Deleting CloudWatch log groups..."
aws logs delete-log-group --region $AWS_REGION \
  --log-group-name /aws/eks/wiz_cluster_eks/cluster 2>/dev/null || echo "Log group already deleted"

aws logs delete-log-group --region $AWS_REGION \
  --log-group-name /aws/eks/wiz-prod-eks/cluster 2>/dev/null || echo "Log group already deleted"

echo ""
echo "[Step 5/7] Resource names updated in code..."
echo "  - EKS cluster: wiz_cluster_eks → wiz-prod-eks"
echo "  - All references updated in Makefile and workflows"

echo ""
echo "[Step 6/7] Committing changes..."
git add -A
git commit -m "feat: clean slate deployment with renamed resources" || echo "Nothing to commit"
git push origin dev

echo ""
echo "[Step 7/7] Instructions for next steps..."
echo ""
echo "=============================================="
echo "✅ Cleanup complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Merge your PR to main on GitHub"
echo "2. GitHub Actions will deploy:"
echo "   - EKS cluster (with new name: wiz-prod-eks)"
echo "   - EC2 + MongoDB"
echo "   - Ansible configuration"
echo ""
echo "Or deploy locally with:"
echo "  AWS_PROFILE=wiz make deploy-all"
echo ""

