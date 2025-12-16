# Variables
APP_NAME := wiz-exercise-app
AWS_REGION := us-east-1
IMAGE_TAG ?= $(shell date +%Y%m%d%H%M%S)

# Required for push/deploy (override via CLI)
ECR_URL ?= ""
MONGO_IP ?= ""
CLUSTER_NAME ?= wiz-securelabs-eks

.PHONY: build push deploy

build:
	docker build -t $(APP_NAME):$(IMAGE_TAG) ./app

push:
	@if [ -z "$(ECR_URL)" ]; then echo "Error: ECR_URL is not set"; exit 1; fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_URL)
	docker tag $(APP_NAME):$(IMAGE_TAG) $(ECR_URL):$(IMAGE_TAG)
	docker push $(ECR_URL):$(IMAGE_TAG)
	@echo "Pushed $(ECR_URL):$(IMAGE_TAG)"

deploy:
	@if [ -z "$(ECR_URL)" ] || [ -z "$(MONGO_IP)" ]; then echo "Error: ECR_URL and MONGO_IP must be set"; exit 1; fi
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	helm upgrade --install wiz-app ./iac/kubernetes/app \
		-f ./iac/kubernetes/app/values-dev.yaml \
		-f ./iac/kubernetes/app/values-override.yaml \
		--set image.repository=$(ECR_URL) \
		--set image.tag=$(IMAGE_TAG) \
		--set mongodb.host=$(MONGO_IP) \
		--wait

clean:
	@echo "⚠️  WARNING: This will destroy ALL resources (App, Mongo, Cluster, Security)."
	@echo "Destroying Application..."
	-helm uninstall wiz-app
	@echo "Destroying EC2 layer (Mongo)..."
	cd iac/envs/dev/ec2 && terraform init && TF_VAR_mongo_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDummyKeyForDestroyOperation==" terraform destroy -auto-approve
	@echo "Destroying EKS layer (Cluster + VPC)..."
	cd iac/envs/dev/eks && terraform init && terraform destroy -auto-approve
	@echo "Destroying Security layer..."
	cd iac/envs/dev/security && terraform init && terraform destroy -auto-approve
	@echo "✅ Cleanup complete!"
