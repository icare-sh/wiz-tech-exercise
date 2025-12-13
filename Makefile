TF_DIR_EKS ?= iac/envs/dev/eks
TF_DIR_EC2 ?= iac/envs/dev/ec2
TF_PLAN ?= tfplan
APP_DIR ?= app
IMAGE_NAME ?= wiz-tech-exercise
IMAGE_TAG ?= latest

.PHONY: eks-fmt eks-init eks-validate eks-plan eks-apply eks-destroy
.PHONY: ec2-fmt ec2-init ec2-validate ec2-plan ec2-apply ec2-destroy
.PHONY: app-build app-run app-scan

eks-fmt:
	terraform -chdir=$(TF_DIR_EKS) fmt -recursive

eks-init:
	terraform -chdir=$(TF_DIR_EKS) init

eks-validate: eks-init
	terraform -chdir=$(TF_DIR_EKS) validate

eks-plan: eks-validate
	terraform -chdir=$(TF_DIR_EKS) plan -out=$(TF_PLAN)

eks-apply: eks-plan
	terraform -chdir=$(TF_DIR_EKS) apply $(TF_PLAN)

eks-destroy: eks-init
	terraform -chdir=$(TF_DIR_EKS) destroy

ec2-fmt:
	terraform -chdir=$(TF_DIR_EC2) fmt -recursive

ec2-init:
	terraform -chdir=$(TF_DIR_EC2) init

ec2-validate: ec2-init
	terraform -chdir=$(TF_DIR_EC2) validate

ec2-plan: ec2-validate
	terraform -chdir=$(TF_DIR_EC2) plan -out=$(TF_PLAN)

ec2-apply: ec2-plan
	terraform -chdir=$(TF_DIR_EC2) apply $(TF_PLAN)

ec2-destroy: ec2-init
	terraform -chdir=$(TF_DIR_EC2) destroy

# --- Milestone 4 : App ---

app-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) $(APP_DIR)

app-run:
	@echo "Running app locally on port 8080..."
	docker run -p 8080:8080 --env-file .env $(IMAGE_NAME):$(IMAGE_TAG)

app-scan:
	@echo "Scanning image with Trivy..."
	# Assumes trivy is installed or run via docker if needed
	trivy image --exit-code 0 --severity HIGH,CRITICAL $(IMAGE_NAME):$(IMAGE_TAG)
