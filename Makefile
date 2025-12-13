TF_DIR_EKS ?= iac/envs/dev/eks
TF_DIR_EC2 ?= iac/envs/dev/ec2
TF_PLAN ?= tfplan

.PHONY: eks-fmt eks-init eks-validate eks-plan eks-apply eks-destroy
.PHONY: ec2-fmt ec2-init ec2-validate ec2-plan ec2-apply ec2-destroy

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
