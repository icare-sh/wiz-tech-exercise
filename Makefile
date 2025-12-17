# Variables
APP_NAME := wiz-exercise-app
AWS_REGION := us-east-1
IMAGE_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)

# Required for push/deploy (override via CLI)
ECR_URL ?= ""
MONGO_IP ?= ""
CLUSTER_NAME ?= wiz-securelabs-eks
SSH_KEY ?= "~/.ssh/id_ed25519"
USER_NAME ?= "ubuntu"
VAULT_PASSWORD ?= "~/.ansible_vault_pass"

.PHONY: build push deploy

build:
	docker build -t $(APP_NAME):$(IMAGE_TAG) ./app

push:
	@if [ -z "$(ECR_URL)" ]; then \
		echo "Fetching ECR_URL from Terraform..."; \
		ECR_URL=$$(cd iac/envs/dev/ec2 && terraform output -raw ecr_repository_url); \
		if [ -z "$$ECR_URL" ]; then echo "Error: Could not fetch ECR_URL"; exit 1; fi; \
		echo "Found ECR_URL: $$ECR_URL"; \
		aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URL; \
		docker tag $(APP_NAME):$(IMAGE_TAG) $$ECR_URL:$(IMAGE_TAG); \
		docker push $$ECR_URL:$(IMAGE_TAG); \
		echo "Pushed $$ECR_URL:$(IMAGE_TAG)"; \
	else \
		aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_URL); \
		docker tag $(APP_NAME):$(IMAGE_TAG) $(ECR_URL):$(IMAGE_TAG); \
		docker push $(ECR_URL):$(IMAGE_TAG); \
		echo "Pushed $(ECR_URL):$(IMAGE_TAG)"; \
	fi

deploy:
	@ECR_URL="$(ECR_URL)"; \
	MONGO_IP="$(MONGO_IP)"; \
	if [ -z "$$ECR_URL" ]; then \
		echo "Fetching ECR_URL from Terraform..."; \
		ECR_URL=$$(cd iac/envs/dev/ec2 && terraform output -raw ecr_repository_url); \
	fi; \
	if [ -z "$$MONGO_IP" ]; then \
		echo "Fetching Mongo IP from Terraform..."; \
		MONGO_IP=$$(cd iac/envs/dev/ec2 && terraform output -raw mongo_private_ip); \
	fi; \
	if [ -z "$$ECR_URL" ] || [ -z "$$MONGO_IP" ]; then echo "Error: ECR_URL and MONGO_IP must be set or fetchable"; exit 1; fi; \
	echo "Deploying with ECR_URL=$$ECR_URL and MONGO_IP=$$MONGO_IP"; \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME); \
	helm upgrade --install wiz-app ./iac/kubernetes/app \
		-f ./iac/kubernetes/app/values-dev.yaml \
		-f ./iac/kubernetes/app/values-override.yaml \
		--set image.repository=$$ECR_URL \
		--set image.tag=$(IMAGE_TAG) \
		--set mongodb.host=$$MONGO_IP \
		--wait

ansible-run:
	@echo "Fetching Mongo IP..."
	$(eval MONGO_IP := $(shell cd iac/envs/dev/ec2 && terraform output -raw mongo_public_ip))
	@echo "Mongo IP: $(MONGO_IP)"
	@if [ -z "$(MONGO_IP)" ]; then echo "Error: Could not get Mongo IP"; exit 1; fi
	@echo "Fetching S3 Bucket Name..."
	$(eval S3_BUCKET := $(shell cd iac/envs/dev/ec2 && terraform output -raw backup_bucket_name))
	@echo "S3 Bucket: $(S3_BUCKET)"
	@if [ -z "$(S3_BUCKET)" ]; then echo "Error: Could not get S3 Bucket Name"; exit 1; fi
	@echo "Running Ansible..."
	cd iac/envs/dev/ansible && \
	ansible-playbook playbook.yml \
	    -i "$(MONGO_IP)," \
	    -u $(USER_NAME) \
	    --private-key $(SSH_KEY) \
	    --extra-vars "@group_vars/mongo/vault.yml" \
	    -e "s3_bucket_name=$(S3_BUCKET)" \
	    --vault-password-file $(VAULT_PASSWORD) \
	    --ssh-common-args='-o StrictHostKeyChecking=no'

helm-status:
	@echo "Fetching Cluster Status..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo "\n>>> Helm Release Status"
	helm status wiz-app
	@echo "\n>>> Kubernetes Resources (Pods, Services/ELB, Ingress)"
	kubectl get pods,svc,ingress
	@echo "\n>>> Ingress Details"
	kubectl describe ingress wiz-exercise-app-ingress || echo "No Ingress found"

clean:
	@echo "WARNING: This will destroy ALL resources (App, Mongo, Cluster, Security)."
	@echo "Destroying Application..."
	-helm uninstall wiz-app
	@echo "Destroying EC2 layer (Mongo)..."
	cd iac/envs/dev/ec2 && terraform init && TF_VAR_mongo_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDummyKeyForDestroyOperation==" terraform destroy -auto-approve
	@echo "Destroying EKS layer (Cluster + VPC)..."
	cd iac/envs/dev/eks && terraform init && terraform destroy -auto-approve
	@echo "Destroying Security layer..."
	cd iac/envs/dev/security && terraform init && terraform destroy -auto-approve
	@echo "Cleanup complete!"
