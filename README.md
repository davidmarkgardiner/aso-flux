# ASO GitOps Platform

A flexible GitOps configuration for Azure Service Operator (ASO) deployments across multiple environments using Kustomize and FluxCD.

## 🏗️ Architecture

This repository implements a GitOps workflow for managing Azure Kubernetes Service (AKS) clusters across dev, ppe, and prd environments using:

- **Azure Service Operator (ASO)**: Manages Azure resources through Kubernetes custom resources
- **Kustomize**: Configuration management with environment-specific overlays
- **FluxCD**: GitOps continuous deployment
- **Node Auto-Provisioning (NAP)**: Dynamic node scaling based on workload requirements

## 📁 Repository Structure

```
aso-flux/
├── base/                           # Base Kustomize configuration
│   ├── kustomization.yaml         # Common labels and resources
│   ├── namespace.yaml             # Default namespace
│   └── managed-cluster.yaml       # Base AKS cluster configuration
├── overlays/                      # Environment-specific overlays
│   ├── dev/                       # Development environment
│   ├── ppe/                       # Pre-production environment
│   └── prd/                       # Production environment
├── flux/                          # FluxCD configurations
│   ├── clusters/                  # Per-environment Flux configs
│   └── environments/              # Flux environment orchestration
├── scripts/                       # Automation scripts
│   ├── update-environment.sh      # Environment variable updates
│   └── validate.sh               # Validation and linting
├── .gitlab-ci.yml                # GitLab CI/CD pipeline
├── .yamllint.yml                 # YAML linting configuration
└── Makefile                      # Development commands
```

## 🚀 Quick Start

### Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kustomize](https://kustomize.io/)
- [flux](https://fluxcd.io/flux/installation/)
- [yamllint](https://yamllint.readthedocs.io/)

### Installation

```bash
# Install all required tools
make install-tools

# Setup development environment
make setup
```

### Validate Configuration

```bash
# Run all validation checks
make validate

# Quick validation (skip security scan)
make validate-quick

# YAML linting only
make lint
```

## 🛠️ Development Workflow

### 1. Environment Updates

Use the provided script to update environment variables:

```bash
# Update dev environment cluster name
./scripts/update-environment.sh dev --cluster-name aks-dev-new

# Update production with multiple values
./scripts/update-environment.sh prd \
  --vm-size Standard_D16s_v3 \
  --security-level high \
  --cluster-name aks-prd-v2

# Preview changes without applying
./scripts/update-environment.sh ppe --cluster-name aks-ppe-test --dry-run
```

### 2. Build Manifests

```bash
# Build specific environment
make build-dev
make build-ppe
make build-prd

# Build all environments
make build
```

### 3. Validation

```bash
# Run comprehensive validation
make validate

# Run pre-commit checks
make pre-commit
```

## 🌍 Environment Configuration

### Development (dev)
- **Resource Group**: `aks-dev-rg`
- **VM Size**: `Standard_D2s_v3`
- **Auto-scaling**: Disabled
- **Security Level**: Standard
- **Sync Interval**: 1 minute

### Pre-Production (ppe)
- **Resource Group**: `aks-ppe-rg`
- **VM Size**: `Standard_D4s_v3`
- **Auto-scaling**: Limited
- **Security Level**: Elevated
- **Sync Interval**: 5 minutes

### Production (prd)
- **Resource Group**: `aks-prd-rg`
- **VM Size**: `Standard_D8s_v3`
- **Auto-scaling**: Full (3-10 nodes)
- **Security Level**: High
- **Sync Interval**: 10 minutes

## 🔄 GitOps Workflow

1. **Configuration Changes**: Update overlay files or use the update script
2. **Validation**: CI/CD pipeline validates all changes
3. **Build**: Manifests are built and artifacts created
4. **Deployment**: FluxCD automatically syncs changes to target clusters
5. **Monitoring**: Health checks ensure successful deployment

## 🔒 Security Features

- **Workload Identity**: Enabled across all environments
- **RBAC**: Azure AD integration with admin group controls
- **Private Networking**: Configurable per environment
- **Image Scanning**: Automated vulnerability scanning
- **Secret Management**: Azure Key Vault integration
- **Security Monitoring**: Defender for Containers (production)

## 📊 Monitoring & Observability

- **Azure Monitor**: Metrics collection enabled
- **Health Checks**: FluxCD monitors cluster health
- **Event Tracking**: Kubernetes events for debugging
- **Workload Autoscaling**: KEDA integration for dynamic scaling

## 🔧 Customization

### Adding New Environments

1. Create overlay directory: `overlays/new-env/`
2. Copy and modify kustomization.yaml and cluster-patch.yaml
3. Add Flux configuration: `flux/clusters/new-env-cluster.yaml`
4. Update environment kustomization: `flux/environments/kustomization.yaml`

### Modifying Cluster Configuration

1. Update base configuration: `base/managed-cluster.yaml`
2. Add environment-specific patches: `overlays/{env}/cluster-patch.yaml`
3. Validate changes: `make validate`
4. Commit and push for GitOps deployment

## 🚨 Troubleshooting

### Common Issues

**Kustomize Build Failures**
```bash
# Check overlay syntax
kustomize build overlays/dev/

# Validate against Kubernetes API
kubectl --dry-run=client apply -f <(kustomize build overlays/dev/)
```

**Flux Sync Issues**
```bash
# Check Flux status
flux get sources git
flux get kustomizations

# Force reconciliation
flux reconcile source git aso-flux-dev
flux reconcile kustomization aso-dev-cluster
```

**Variable Substitution Problems**
```bash
# Test variable replacement
./scripts/update-environment.sh dev --cluster-name test-cluster --dry-run
```

## 📚 Additional Resources

- [Azure Service Operator Documentation](https://azure.github.io/azure-service-operator/)
- [Kustomize Documentation](https://kustomize.io/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [AKS Best Practices](./aks-best-practices.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and validate: `make validate`
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.