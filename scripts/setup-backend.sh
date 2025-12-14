#!/bin/bash
set -e

echo "========================================"
echo "Wiz Tech Exercise - Backend Setup"
echo "========================================"
echo ""

AWS_PROFILE="${AWS_PROFILE:-wiz}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Using AWS Profile: $AWS_PROFILE"
echo "Using AWS Region: $AWS_REGION"
echo ""

cd "$(dirname "$0")/../iac/terraform-backend"

echo "[1/3] Deploying S3 bucket and DynamoDB table..."
terraform init
terraform apply -auto-approve

BUCKET_NAME=$(terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)

echo ""
echo " Backend infrastructure created:"
echo "   S3 Bucket: $BUCKET_NAME"
echo "   DynamoDB Table: $DYNAMODB_TABLE"
echo ""

echo "[2/3] Creating backend.tf files for each module..."

cd ..

for MODULE_DIR in "envs/dev/eks" "envs/dev/ec2" "github-oidc"; do
    if [ -f "$MODULE_DIR/backend.tf.example" ]; then
        BACKEND_FILE="$MODULE_DIR/backend.tf"
        
        sed "s/wiz-tech-exercise-terraform-state-180294187104/$BUCKET_NAME/g" \
            "$MODULE_DIR/backend.tf.example" > "$BACKEND_FILE"
        
        sed -i "s/wiz-tech-exercise-terraform-locks/$DYNAMODB_TABLE/g" "$BACKEND_FILE"
        
        echo "   ✓ Created $BACKEND_FILE"
    fi
done

echo ""
echo "[3/3] Migrating existing state to S3 (if any)..."
echo ""

for MODULE_DIR in "envs/dev/eks" "envs/dev/ec2" "github-oidc"; do
    if [ -f "$MODULE_DIR/backend.tf" ]; then
        echo "Migrating $MODULE_DIR..."
        cd "$MODULE_DIR"
        
        if [ -f "terraform.tfstate" ]; then
            echo "yes" | terraform init -migrate-state || true
            echo "   ✓ State migrated for $MODULE_DIR"
        else
            terraform init
            echo "   ✓ Backend configured for $MODULE_DIR (no existing state)"
        fi
        
        cd - > /dev/null
    fi
done

echo ""
echo "========================================"
echo " Backend setup complete!"
echo "========================================"
echo ""
echo "Backend Configuration:"
echo "  Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $AWS_REGION"
echo ""
echo "All Terraform modules now use remote state storage."
echo "GitHub Actions CI/CD will automatically use this backend."
echo ""

