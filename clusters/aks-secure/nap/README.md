# Node Auto-Provisioning (NAP) Configurations

This directory contains configurations for AKS Node Auto-Provisioning with Karpenter, providing specialized node pools for different workload types.

## Included Configurations

### High-Performance Workloads

The `high-performance` directory contains configurations for compute-intensive workloads:
- `nodepool.yaml` - Defines a NodePool using F-series VMs with high CPU and memory requirements
- `policy.yaml` - Kyverno policy to automatically route high-performance workloads to the right nodes
- `test.yaml` - Test deployment to verify the high-performance configuration

### Infrastructure Workloads

The `infrastructure` directory contains configurations for stable infrastructure services:
- `nodepool.yaml` - Defines a NodePool using D-series VMs with stable on-demand instances
- `policy.yaml` - Kyverno policy to route infrastructure workloads with high availability constraints
- `test.yaml` - Test deployment to verify the infrastructure configuration

### Tests

The `tests` directory contains additional test deployments to verify the configuration.

## Usage

These configurations are automatically applied by Flux. The Kyverno policies will automatically:

1. Add appropriate tolerations to pods
2. Add node affinity to route pods to the right node types
3. Add pod anti-affinity for better distribution
4. Add topology spread constraints for high availability

## Testing

To test the configurations, apply the test deployments and verify that pods are scheduled on the correct nodes:

```bash
kubectl get pods -n test-high-perf -o wide
kubectl get pods -n test-infra -o wide
```