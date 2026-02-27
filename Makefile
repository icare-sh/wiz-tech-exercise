# Variables
APP_NAME := wiz-exercise-app
AWS_REGION := us-east-1
IMAGE_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)

# Required for push/deploy (override via CLI or fetched from Terraform)
ECR_URL ?=
MONGO_IP ?=
CLUSTER_NAME ?= wiz-securelabs-eks
SSH_KEY ?= ~/.ssh/id_ed25519
USER_NAME ?= ubuntu
VAULT_PASSWORD ?= ~/.ansible_vault_pass

# Sensitive values for deploy (pass via CLI: make deploy MONGO_PASSWORD=xxx SECRET_KEY=xxx)
MONGO_PASSWORD ?=
SECRET_KEY ?=
WAF_ACL_ARN ?=

.PHONY: build push deploy ansible-run helm-status clean

# ---------------------------------------------------------------------------
# Build the Docker image locally
# ---------------------------------------------------------------------------
build:
	docker build -t $(APP_NAME):$(IMAGE_TAG) ./app

# ---------------------------------------------------------------------------
# Push Docker image to ECR
# ---------------------------------------------------------------------------
push:
	@ECR_URL="$(ECR_URL)"; \
	if [ -z "$$ECR_URL" ]; then \
		echo "Fetching ECR_URL from Terraform..."; \
		ECR_URL=$$(cd iac/envs/dev/ec2 && terraform output -raw ecr_repository_url); \
	fi; \
	if [ -z "$$ECR_URL" ]; then echo "Error: Could not determine ECR_URL"; exit 1; fi; \
	echo "ECR_URL: $$ECR_URL"; \
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URL; \
	docker tag $(APP_NAME):$(IMAGE_TAG) $$ECR_URL:$(IMAGE_TAG); \
	docker push $$ECR_URL:$(IMAGE_TAG); \
	echo "Pushed $$ECR_URL:$(IMAGE_TAG)"

# ---------------------------------------------------------------------------
# Deploy to EKS via Helm (mirrors cd-release.yml pipeline)
# ---------------------------------------------------------------------------
deploy:
	@ECR_URL="$(ECR_URL)"; \
	MONGO_IP="$(MONGO_IP)"; \
	WAF_ACL_ARN="$(WAF_ACL_ARN)"; \
	if [ -z "$$ECR_URL" ]; then \
		echo "Fetching ECR_URL from Terraform..."; \
		ECR_URL=$$(cd iac/envs/dev/ec2 && terraform output -raw ecr_repository_url); \
	fi; \
	if [ -z "$$MONGO_IP" ]; then \
		echo "Fetching Mongo IP from Terraform..."; \
		MONGO_IP=$$(cd iac/envs/dev/ec2 && terraform output -raw mongo_private_ip); \
	fi; \
	if [ -z "$$WAF_ACL_ARN" ]; then \
		echo "Fetching WAF ACL ARN from Terraform..."; \
		WAF_ACL_ARN=$$(cd iac/envs/dev/eks && terraform output -raw waf_acl_arn 2>/dev/null) || true; \
	fi; \
	if [ -z "$$ECR_URL" ] || [ -z "$$MONGO_IP" ]; then echo "Error: ECR_URL and MONGO_IP must be set or fetchable"; exit 1; fi; \
	echo "Deploying with ECR_URL=$$ECR_URL MONGO_IP=$$MONGO_IP"; \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME); \
	helm upgrade --install wiz-app ./iac/kubernetes/app \
		-f ./iac/kubernetes/app/values-dev.yaml \
		--set image.repository=$$ECR_URL \
		--set image.tag=$(IMAGE_TAG) \
		--set mongodb.host=$$MONGO_IP \
		--set mongodb.username=admin \
		--set mongodb.password="$(MONGO_PASSWORD)" \
		--set secrets.secretKey="$(SECRET_KEY)" \
		--set ingress.wafAclArn="$$WAF_ACL_ARN" \
		--set environment=dev \
		--wait

# ---------------------------------------------------------------------------
# Run Ansible playbook against MongoDB VM
# ---------------------------------------------------------------------------
ansible-run:
	@MONGO_IP="$(MONGO_IP)"; \
	S3_BUCKET="$(S3_BUCKET)"; \
	if [ -z "$$MONGO_IP" ]; then \
		echo "Fetching Mongo IP from Terraform..."; \
		MONGO_IP=$$(cd iac/envs/dev/ec2 && terraform output -raw mongo_public_ip); \
	fi; \
	if [ -z "$$S3_BUCKET" ]; then \
		echo "Fetching S3 Bucket Name from Terraform..."; \
		S3_BUCKET=$$(cd iac/envs/dev/ec2 && terraform output -raw backup_bucket_name); \
	fi; \
	if [ -z "$$MONGO_IP" ] || [ -z "$$S3_BUCKET" ]; then echo "Error: Could not get Mongo IP or S3 Bucket"; exit 1; fi; \
	echo "Running Ansible on $$MONGO_IP with Bucket $$S3_BUCKET..."; \
	cd iac/envs/dev/ansible && \
	ansible-playbook playbook.yml \
		-i "$$MONGO_IP," \
		-u $(USER_NAME) \
		--private-key $(SSH_KEY) \
		--extra-vars "@group_vars/mongo/vault.yml" \
		-e "s3_bucket_name=$$S3_BUCKET" \
		--vault-password-file $(VAULT_PASSWORD) \
		--ssh-common-args='-o StrictHostKeyChecking=no'

# ---------------------------------------------------------------------------
# Show deployment status
# ---------------------------------------------------------------------------
helm-status:
	@echo "Fetching Cluster Status..."
	@aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME) 2>/dev/null
	@echo ""
	@echo ">>> Helm Release Status"
	@helm status wiz-app 2>/dev/null || echo "Release 'wiz-app' not found"
	@echo ""
	@echo ">>> Kubernetes Resources (Pods, Services, Ingress)"
	@kubectl get pods,svc,ingress
	@echo ""
	@echo ">>> Application URL"
	@kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null && echo "" || echo "No ALB hostname found"

# ---------------------------------------------------------------------------
# Destroy everything (reverse order of creation)
# ---------------------------------------------------------------------------
clean:
	@echo "WARNING: This will destroy ALL resources (App, Mongo, Cluster, Security)."
	@echo ""
	@echo ">>> Step 1/4: Destroying Application (Helm release)..."
	-helm uninstall wiz-app 2>/dev/null; true
	@echo "Waiting for ALB cleanup..."
	@sleep 30
	@echo ""
	@echo ">>> Step 2/4: Destroying EC2 layer (Mongo + ECR + S3 + SSM)..."
	cd iac/envs/dev/ec2 && terraform init -input=false && \
		TF_VAR_mongo_ssh_public_key="dummy" \
		TF_VAR_mongo_admin_password="dummy" \
		TF_VAR_app_secret_key="dummy" \
		terraform destroy -auto-approve
	@echo ""
	@echo ">>> Step 3/4: Destroying EKS layer (Cluster + VPC + Falco + WAF + ALB Controller)..."
	cd iac/envs/dev/eks && terraform init -input=false && terraform destroy -auto-approve
	@echo ""
	@echo ">>> Step 4/4: Destroying Security layer (CloudTrail + GuardDuty + Config + Inspector)..."
	cd iac/envs/dev/security && terraform init -input=false && terraform destroy -auto-approve
	@echo ""
	@echo "Cleanup complete!"
