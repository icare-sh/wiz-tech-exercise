TF_DIR_EKS ?= iac/envs/dev/eks
TF_DIR_EC2 ?= iac/envs/dev/ec2
TF_PLAN ?= tfplan
APP_DIR ?= app
IMAGE_NAME ?= wiz-tech-exercise
IMAGE_TAG ?= latest
ANSIBLE_DIR ?= iac/envs/dev/ansible
ANSIBLE_VAULT_PASS_FILE ?= ~/.ansible_vault_pass
HELM_CHART ?= iac/kubernetes/app
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= 180294187104

.PHONY: eks-fmt eks-init eks-validate eks-plan eks-apply eks-destroy eks-outputs
.PHONY: ec2-fmt ec2-init ec2-validate ec2-plan ec2-apply ec2-destroy ec2-outputs
.PHONY: app-build app-run app-scan app-push
.PHONY: ansible-setup ansible-run ansible-create-vault-pass
.PHONY: helm-setup helm-deploy helm-status
.PHONY: deploy-all clean-all setup-cicd setup-backend verify-states fix-state-corruption

eks-fmt:
	terraform -chdir=$(TF_DIR_EKS) fmt -recursive

eks-init:
	terraform -chdir=$(TF_DIR_EKS) init -reconfigure

eks-validate: eks-init
	terraform -chdir=$(TF_DIR_EKS) validate

eks-plan: eks-validate
	terraform -chdir=$(TF_DIR_EKS) plan -out=$(TF_PLAN)

eks-apply: eks-plan
	terraform -chdir=$(TF_DIR_EKS) apply $(TF_PLAN)
	@echo "Verifying state was saved..."
	@terraform -chdir=$(TF_DIR_EKS) state list || (echo "ERROR: State is empty!" && exit 1)

eks-outputs:
	@terraform -chdir=$(TF_DIR_EKS) output -json

eks-destroy: eks-init
	terraform -chdir=$(TF_DIR_EKS) destroy

ec2-fmt:
	terraform -chdir=$(TF_DIR_EC2) fmt -recursive

ec2-init:
	terraform -chdir=$(TF_DIR_EC2) init -reconfigure

ec2-validate: ec2-init
	terraform -chdir=$(TF_DIR_EC2) validate

ec2-plan: ec2-validate
	terraform -chdir=$(TF_DIR_EC2) plan -out=$(TF_PLAN)

ec2-apply: ec2-plan
	terraform -chdir=$(TF_DIR_EC2) apply $(TF_PLAN)
	@echo "Verifying state was saved..."
	@terraform -chdir=$(TF_DIR_EC2) state list || (echo "ERROR: State is empty!" && exit 1)

ec2-outputs:
	@terraform -chdir=$(TF_DIR_EC2) output -json

ec2-destroy: ec2-init
	terraform -chdir=$(TF_DIR_EC2) destroy

app-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) $(APP_DIR)

app-run:
	@echo "Running app locally on port 8080..."
	docker run -p 8080:8080 --env-file .env $(IMAGE_NAME):$(IMAGE_TAG)

app-scan:
	@echo "Scanning image with Trivy..."
	trivy image --exit-code 0 --severity HIGH,CRITICAL $(IMAGE_NAME):$(IMAGE_TAG)

app-push:
	@echo "Tagging and pushing to ECR..."
	@ECR_URL=$$(terraform -chdir=$(TF_DIR_EC2) output -raw ecr_repository_url); \
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com; \
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $$ECR_URL:$(IMAGE_TAG); \
	docker push $$ECR_URL:$(IMAGE_TAG)

ansible-setup:
	@echo "Updating Ansible inventory with Terraform outputs..."
	@MONGO_IP=$$(terraform -chdir=$(TF_DIR_EC2) output -raw mongo_public_ip); \
	BUCKET=$$(terraform -chdir=$(TF_DIR_EC2) output -raw backup_bucket_name); \
	sed -i "s/^mongo_host ansible_host=.*/mongo_host ansible_host=$$MONGO_IP ansible_user=ubuntu ansible_ssh_private_key_file=~\/.ssh\/id_ed25519 ansible_ssh_common_args='-o StrictHostKeyChecking=no'/" $(ANSIBLE_DIR)/inventory; \
	sed -i "s/^s3_bucket_name: .*/s3_bucket_name: $$BUCKET/" $(ANSIBLE_DIR)/group_vars/mongo/vars.yml

ansible-run:
	@echo "Running Ansible playbook..."
	@if [ -f $(ANSIBLE_VAULT_PASS_FILE) ]; then \
		ansible-playbook -i $(ANSIBLE_DIR)/inventory $(ANSIBLE_DIR)/mongo.yml --vault-password-file $(ANSIBLE_VAULT_PASS_FILE); \
	else \
		ansible-playbook -i $(ANSIBLE_DIR)/inventory $(ANSIBLE_DIR)/mongo.yml --ask-vault-pass; \
	fi

ansible-create-vault-pass:
	@echo "Creating Ansible Vault password file..."
	@read -sp "Enter Ansible Vault password: " VAULT_PASS; \
	echo "$$VAULT_PASS" > $(ANSIBLE_VAULT_PASS_FILE); \
	chmod 600 $(ANSIBLE_VAULT_PASS_FILE); \
	echo "\nVault password saved to $(ANSIBLE_VAULT_PASS_FILE)"

helm-setup:
	@echo "Adding Helm repos..."
	helm repo add eks https://aws.github.io/eks-charts
	helm repo update
	@echo "Updating kubeconfig..."
	@CLUSTER_NAME=$$(terraform -chdir=$(TF_DIR_EKS) output -raw cluster_name); \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $$CLUSTER_NAME

helm-deploy:
	@echo "Deploying AWS Load Balancer Controller..."
	@CLUSTER_NAME=$$(terraform -chdir=$(TF_DIR_EKS) output -raw cluster_name); \
	LB_ROLE_ARN=$$(terraform -chdir=$(TF_DIR_EKS) output -raw lb_controller_role_arn); \
	helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
	  -n kube-system \
	  --set clusterName=$$CLUSTER_NAME \
	  --set serviceAccount.create=true \
	  --set serviceAccount.name=aws-load-balancer-controller \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$$LB_ROLE_ARN
	@echo "Waiting for ALB Controller to be ready..."
	@kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system || true
	@echo "Deploying application..."
	@MONGO_IP=$$(terraform -chdir=$(TF_DIR_EC2) output -raw mongo_private_ip); \
	ECR_URL=$$(terraform -chdir=$(TF_DIR_EC2) output -raw ecr_repository_url); \
	helm upgrade --install wiz-app $(HELM_CHART) \
	  -f $(HELM_CHART)/values-dev.yaml \
	  --set image.repository=$$ECR_URL \
	  --set image.tag=latest \
	  --set mongodb.host=$$MONGO_IP \
	  --set mongodb.username=admin \
	  --set mongodb.password="$${MONGO_PASSWORD:-SuperSecretPassword123!}" \
	  --set secrets.secretKey="$${APP_SECRET_KEY:-dev-secret-key}" \
	  --set environment=dev

helm-status:
	@echo "=== Pods ==="
	@kubectl get pods
	@echo "\n=== Services ==="
	@kubectl get svc
	@echo "\n=== Ingress ==="
	@kubectl get ingress
	@echo "\n=== ALB URL ==="
	@kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
	@echo ""

deploy-all:
	@echo "Starting full deployment..."
	@echo "\n[1/6] Deploying EKS cluster..."
	@make eks-apply
	@echo "\n[2/6] Deploying EC2 MongoDB instance..."
	@make ec2-apply
	@echo "\n[3/6] Configuring Ansible inventory..."
	@make ansible-setup
	@echo "\n[4/6] Installing MongoDB with Ansible..."
	@make ansible-run
	@echo "\n[5/6] Building and pushing Docker image..."
	@make app-build app-push
	@echo "\n[6/6] Setting up Helm and deploying application..."
	@make helm-setup helm-deploy
	@echo "\n=== Deployment Complete ==="
	@make helm-status

clean-all:
	@echo "Destroying all infrastructure..."
	@make ec2-destroy
	@make eks-destroy
	@echo "Cleanup complete"

setup-backend:
	@echo "Setting up Terraform remote backend (S3 + DynamoDB)..."
	@cd iac/terraform-backend && terraform init && terraform apply
	@echo "\n✅ Backend created. Now configure backend.tf in each module:"
	@echo "\nBucket: $$(cd iac/terraform-backend && terraform output -raw s3_bucket_name)"
	@echo "DynamoDB Table: $$(cd iac/terraform-backend && terraform output -raw dynamodb_table_name)"
	@echo "\nSee iac/terraform-backend/README.md for migration steps"

setup-cicd:
	@echo "Setting up CI/CD infrastructure..."
	@echo "1. Deploy GitHub OIDC provider and IAM role..."
	@cd iac/github-oidc && terraform init && terraform apply
	@echo "\n2. Retrieve GitHub Actions Role ARN..."
	@cd iac/github-oidc && terraform output github_actions_role_arn
	@echo "\n3. Add this ARN to GitHub Secrets as AWS_GITHUB_ACTIONS_ROLE_ARN"
	@echo "\nCI/CD setup complete!"

verify-states:
	@echo "Verifying Terraform states in S3..."
	@./scripts/verify-states.sh

fix-state-corruption:
	@echo "Fixing Terraform state corruption (S3/DynamoDB checksum mismatch)..."
	@./scripts/fix-state-corruption.sh

