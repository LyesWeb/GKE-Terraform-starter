# Makefile for Terraform GKE Project
.DEFAULT_GOAL := help
.PHONY: help init plan apply destroy validate fmt clean check-gcloud

# Variables
TF_VARS_FILE ?= terraform.tfvars
TF_PLAN_FILE ?= tfplan
GKE_CLUSTER_NAME ?= $(shell terraform output -raw cluster_name 2>/dev/null)

## —— Terraform & GKE Automation ———————————————————————————————————————————————————————————
help:  ## Show this help menu
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-gcloud:  ## Verify gcloud authentication
	@if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then \
		echo "ERROR: No active gcloud account. Run 'gcloud auth login' first."; \
		exit 1; \
	fi

init: check-gcloud  ## Initialize Terraform
	terraform init -upgrade

validate:  ## Validate Terraform configs
	terraform validate

fmt:  ## Format Terraform code
	terraform fmt -recursive

plan: init validate  ## Generate Terraform plan
	terraform plan -out=$(TF_PLAN_FILE)

apply: plan  ## Apply Terraform changes (requires approval)
	terraform apply $(TF_PLAN_FILE)

apply-auto: plan  ## Apply Terraform changes automatically (DANGER: no approval)
	terraform apply -auto-approve $(TF_PLAN_FILE)

destroy:  ## Destroy Terraform-managed infrastructure
	terraform destroy -auto-approve

output:  ## Show Terraform outputs
	terraform output

## —— GKE Cluster Access ————————————————————————————————————————————————————————————————
get-credentials: check-gcloud  ## Fetch GKE cluster credentials
	@gcloud container clusters get-credentials $(GKE_CLUSTER_NAME) \
		--region $(shell terraform output -raw region)

kube-config: get-credentials  ## Update kubeconfig
	@echo "✓ Kubeconfig updated for cluster: $(GKE_CLUSTER_NAME)"

## —— Utilities ————————————————————————————————————————————————————————————————————————
clean:  ## Clean Terraform and temporary files
	rm -rf .terraform* terraform.tfstate* $(TF_PLAN_FILE) *.log

list-versions:  ## List available Terraform versions
	@gcloud container get-server-config --region $(shell terraform output -raw region) \
		--format="value(validMasterVersions)"

## —— Safety Checks —————————————————————————————————————————————————————————————————————
confirm:
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]