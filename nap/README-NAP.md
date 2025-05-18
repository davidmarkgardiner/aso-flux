# AKS with Node Auto-Provisioning (NAP)

This directory contains configurations for deploying an Azure Kubernetes Service (AKS) cluster with Node Auto-Provisioning (NAP) using Azure Service Operator (ASO).

## Key Files

- `improved-cluster-working.yaml`: Main AKS cluster configuration with NAP enabled
- `node-classes.yaml`: Additional agent pool configurations for NAP to use
- `nap-test.yaml`: Test workloads to verify NAP functionality
- `deploy.sh`: Deployment script to create all resources

## Node Auto-Provisioning Features

The AKS cluster is configured with Node Auto-Provisioning with the following key settings:

```yaml
nodeProvisioningProfile:
  mode: Auto
```

With NAP enabled:
1. AKS automatically provisions nodes based on pod requirements
2. No manual node pool scaling needed
3. Pods get scheduled on the most appropriate node type

## Important Configuration Notes

1. **Agent Pools with NAP**:
   - All agent pools must have `enableAutoScaling: false` when using NAP
   - System pool is configured with small VM size for cost efficiency

2. **Requirements for NAP**:
   - Azure CNI Overlay with Cilium networking is required
   - Managed identity authentication is required
   - Only Linux nodes are supported

3. **Testing NAP**:
   - Test workloads with different resource requirements in `nap-test.yaml`
   - Includes CPU-intensive, memory-intensive, and batch processing workloads

## Monitoring NAP Activity

After deployment is complete, you can monitor NAP with:

```bash
# Check overall cluster status
kubectl get managedcluster aks-secure -n default

# Check provisioned nodes
kubectl get nodes

# Check NAP-managed pods
kubectl get pods -n nap-test -o wide

# Check the events for NAP activities
kubectl get events -n nap-test
```

## Troubleshooting

- If pods remain pending, check the cluster status with:
  ```bash
  kubectl get managedcluster aks-secure -n default -o yaml
  ```

- For issues with the node pools:
  ```bash
  kubectl get managedclustersagentpool -n default
  ```

## Security Features

The cluster is configured with security best practices:
- Workload identity enabled
- Private cluster with RBAC
- Azure KeyVault integration
- Image cleaner for security