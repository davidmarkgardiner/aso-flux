.PHONY: help validate build lint security test clean install-tools

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

validate: ## Run all validation checks
	@echo "Running validation..."
	./scripts/validate.sh

validate-quick: ## Run validation without security scan
	@echo "Running quick validation..."
	./scripts/validate.sh --skip-security

lint: ## Run YAML linting
	@echo "Running YAML lint..."
	yamllint -c .yamllint.yml .

build-dev: ## Build dev environment manifests
	@echo "Building dev manifests..."
	kustomize build overlays/dev/ > build/dev-manifests.yaml

build-ppe: ## Build ppe environment manifests
	@echo "Building ppe manifests..."
	kustomize build overlays/ppe/ > build/ppe-manifests.yaml

build-prd: ## Build prd environment manifests
	@echo "Building prd manifests..."
	kustomize build overlays/prd/ > build/prd-manifests.yaml

build-flux: ## Build flux manifests
	@echo "Building flux manifests..."
	kustomize build flux/environments/ > build/flux-manifests.yaml

build: build-dev build-ppe build-prd build-flux ## Build all manifests
	@echo "All manifests built successfully"

security: ## Run security scan
	@echo "Running security scan..."
	@grep -ri "password\|secret\|key\|token" --include="*.yaml" --include="*.yml" . || echo "No sensitive information found"

test: validate ## Run tests (alias for validate)

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -f /tmp/*-validation.yaml

update-dev: ## Update dev environment (interactive)
	@echo "Updating dev environment..."
	./scripts/update-environment.sh dev

update-ppe: ## Update ppe environment (interactive)
	@echo "Updating ppe environment..."
	./scripts/update-environment.sh ppe

update-prd: ## Update prd environment (interactive)
	@echo "Updating prd environment..."
	./scripts/update-environment.sh prd

install-tools: ## Install required tools
	@echo "Installing required tools..."
	@command -v kustomize >/dev/null 2>&1 || { echo "Installing kustomize..."; curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash; sudo mv kustomize /usr/local/bin/; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Installing kubectl..."; curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; chmod +x kubectl; sudo mv kubectl /usr/local/bin/; }
	@command -v flux >/dev/null 2>&1 || { echo "Installing flux..."; curl -s https://fluxcd.io/install.sh | sudo bash; }
	@command -v yamllint >/dev/null 2>&1 || { echo "Installing yamllint..."; pip3 install yamllint; }

pre-commit: validate ## Run pre-commit checks
	@echo "Running pre-commit checks..."

setup: install-tools ## Setup development environment
	@echo "Setting up development environment..."
	mkdir -p build/
	@echo "Development environment ready!"