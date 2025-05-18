# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Kubernetes configurations for deploying and managing Azure Kubernetes Service (AKS) clusters with the following components:

- **Azure Service Operator (ASO)**: Manages Azure resources through Kubernetes custom resources
- **Flux**: GitOps controller for automatically syncing cluster state with repository configuration
- **Node Auto-Provisioning (NAP)**: Dynamically scales nodes based on workload requirements

## Architecture

1. **Base Layer**: Common configurations shared across all clusters
   - Located in `/base` directory

2. **Cluster-Specific Configs**: Environment-specific configurations
   - Located in `/clusters/<cluster-name>` directories
   - Currently includes `aks-secure` cluster

3. **Node Auto-Provisioning**: Dynamic node scaling configurations
   - Defines different node pools for various workload types
   - Located in `/clusters/aks-secure/nap` directory

4. **Flux GitOps Integration**: 
   - Configured to watch this Git repository for changes
   - Applies changes automatically to the target clusters
   - Configuration in `/aso/flux/fluxconfig.yaml`

## Common Commands

### Deployment Commands

```bash
# Deploy the ASO cluster and resources
chmod +x /Users/davidgardiner/Desktop/repo/aso-flux/aso/deploy.sh
./aso/deploy.sh

# Verify Flux installation
kubectl get extension aso-flux-extension -n default
kubectl get fluxconfiguration aso-flux-config -n default
```

### Monitoring Commands

```bash
# Check cluster status
kubectl get managedcluster aks-secure -n default

# Check node provisioning
kubectl get nodeclaim -n default
kubectl get nodeclass -n default

# Monitor workloads
kubectl get pods -n nap-test -o wide
kubectl get events -n nap-test
```

### Debugging Commands

```bash
# Check Flux controllers
kubectl get deployment -n flux-system

# Check Flux GitRepository resource
kubectl get gitrepository -n flux-system

# Check Flux logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

## Development Workflow

1. Make changes to configuration files in this repository
2. Commit and push changes to the main branch
3. Flux will automatically detect and apply changes to the cluster
4. Verify changes using the monitoring commands above

## Important Configuration Files

- **Cluster Variables**: `/aso/cluster-variables.yaml` defines environment-specific settings
- **Flux Configuration**: `/aso/flux/fluxconfig.yaml` defines GitOps integration
- **Node Classes**: `/clusters/aks-secure/nap/{infrastructure,high-performance}/nodepool.yaml` defines node types