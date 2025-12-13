TF_DIR ?= iac/envs/dev
TF_PLAN ?= tfplan

.PHONY: fmt init validate plan apply destroy

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

init:
	cd $(TF_DIR) && terraform init

validate: init
	cd $(TF_DIR) && terraform validate

plan: validate
	cd $(TF_DIR) && terraform plan -out=$(TF_PLAN)

apply: plan
	cd $(TF_DIR) && terraform apply $(TF_PLAN)

destroy: init
	cd $(TF_DIR) && terraform destroy


