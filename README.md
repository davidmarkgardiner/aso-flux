# AKS with ASO Flux Configuration

This repository contains Kubernetes configurations for an AKS cluster with Node Auto-Provisioning (NAP) managed via Flux.

## Directory Structure

```
├── base                  # Base configurations shared across all clusters
│   ├── kustomization.yaml
│   └── namespace.yaml
└── clusters              # Cluster-specific configurations
    └── aks-secure        # Configuration for aks-secure cluster
        ├── deployment.yaml
        ├── kustomization.yaml
        └── service.yaml
```

## Flux Integration

This repository is integrated with AKS via Azure's Flux extension. It automatically reconciles the Kubernetes state with the configuration in this repository.

## Adding New Applications

To add new applications:

1. Create a new directory in the appropriate location
2. Add the Kubernetes manifests
3. Update the corresponding `kustomization.yaml`
4. Push changes to the main branch

Flux will automatically apply the new configurations to the cluster.

## Testing and Verification

After Flux applies configurations, you can verify that they've been applied correctly with:

```bash
kubectl get all -n demo-app
```