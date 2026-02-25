#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ENV="${ENV:-dev}"

echo "Fetching secrets from AWS SSM Parameter Store (env: $ENV)..."

export MONGODB_URI
MONGODB_URI=$(aws ssm get-parameter \
  --name "/wiz-exercise/${ENV}/mongodb-uri" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION")

export SECRET_KEY
SECRET_KEY=$(aws ssm get-parameter \
  --name "/wiz-exercise/${ENV}/secret-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION")

echo "Secrets loaded. Starting application..."
cd "$(dirname "$0")/../app"
go run main.go
