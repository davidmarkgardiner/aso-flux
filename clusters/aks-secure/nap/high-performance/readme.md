I'll create a complete example for a high-performance workload, including the NodePool configuration and Kyverno policy, along with a test deployment.

```yaml:nap/clusterpolicy/high-performance/nodepool.yaml
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: high-perf-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: high-perf-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never  # High-performance nodes should be stable
  template:
    metadata:
      labels:
        node-type: high-performance
    spec:
      nodeClassRef:
        name: high-perf-nodes
      taints:
        - key: "workload-type"
          value: "high-performance"
          effect: "NoSchedule"
      requirements:
        - key: "kubernetes.io/os"
          operator: In
          values: ["linux"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]  # Use stable on-demand instances
        - key: "karpenter.azure.com/sku-family"
          operator: In
          values: ["F"]  # F-series for compute-optimized workloads
        - key: "karpenter.azure.com/sku-cpu"
          operator: Gt
          values: ["8"]  # Minimum 8 CPUs
        - key: "karpenter.azure.com/sku-memory"
          operator: Gt
          values: ["16384"]  # Minimum 16GB memory
```

```yaml:nap/clusterpolicy/high-performance/policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: route-high-perf-workloads
  annotations:
    policies.kyverno.io/title: Route High Performance Workloads
    policies.kyverno.io/category: Workload Distribution
    policies.kyverno.io/subject: Deployment
    policies.kyverno.io/description: >-
      This policy adds node affinity and tolerations to route high performance workloads
      to compute-optimized nodes based on namespace labels.
spec:
  validationFailureAction: audit
  rules:
    - name: route-high-perf-workloads
      match:
        any:
        - resources:
            kinds:
              - Deployment
            namespaceSelector:
              matchExpressions:
                - key: workload-type
                  operator: In
                  values:
                    - high-performance
      preconditions:
        all:
        - key: "{{ request.object.spec.template.metadata.labels.app || '' }}"
          operator: NotEquals
          value: ""
      mutate:
        patchStrategicMerge:
          spec:
            template:
              spec:
                +(tolerations):
                  - key: "workload-type"
                    operator: "Equal"
                    value: "high-performance"
                    effect: "NoSchedule"
                +(affinity):
                  nodeAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                      nodeSelectorTerms:
                      - matchExpressions:
                        - key: node-type
                          operator: In
                          values:
                            - high-performance
                  podAntiAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                    - weight: 100
                      podAffinityTerm:
                        labelSelector:
                          matchExpressions:
                          - key: app
                            operator: In
                            values:
                            - "{{ request.object.spec.template.metadata.labels.app }}"
                        topologyKey: kubernetes.io/hostname
```

```yaml:nap/clusterpolicy/high-performance/test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-high-perf
  labels:
    workload-type: high-performance
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-compute-intensive
  namespace: test-high-perf
spec:
  replicas: 2
  selector:
    matchLabels:
      app: compute-job
  template:
    metadata:
      labels:
        app: compute-job
    spec:
      containers:
      - name: compute-worker
        image: nginx:1.25  # Using nginx as a placeholder
        resources:
          requests:
            cpu: "4"
            memory: "8Gi"
          limits:
            cpu: "8"
            memory: "16Gi"
        # In a real scenario, you might use a compute-intensive image
        # and add compute-intensive tasks
```


I've created a complete example for high-performance workloads. Here's what each file does:

1. **NodePool Configuration** (`nodepool.yaml`):
   - Uses F-series VMs (compute-optimized)
   - Minimum 8 CPUs and 16GB memory
   - Uses on-demand instances for stability
   - Never expires nodes
   - Adds appropriate labels and taints
   - Uses AzureLinux for the OS

2. **Kyverno Policy** (`policy.yaml`):
   - Matches namespaces labeled with `workload-type: high-performance`
   - Adds required tolerations for high-performance nodes
   - Sets node affinity to target high-performance nodes
   - Adds pod anti-affinity for better distribution
   - Includes precondition to check for app label

3. **Test Deployment** (`test.yaml`):
   - Creates a namespace with the required label
   - Deploys a compute-intensive workload (using nginx as placeholder)
   - Requests significant CPU and memory resources
   - Includes proper labels for policy matching

To test this setup:

1. First, apply the NodePool and policy:
```bash
kubectl apply -f nap/clusterpolicy/high-performance/nodepool.yaml
kubectl apply -f nap/clusterpolicy/high-performance/policy.yaml
```

2. Then apply the test deployment:
```bash
kubectl apply -f nap/clusterpolicy/high-performance/test.yaml
```

3. Verify the deployment:
```bash
kubectl get pods -n test-high-perf
kubectl describe deployment -n test-high-perf test-compute-intensive
```

The deployment should:
- Get scheduled on nodes with the high-performance label
- Have the correct tolerations and affinity rules
- Request appropriate resources for compute-intensive work

Would you like me to:
1. Add more specific resource requirements?
2. Modify the node selection criteria?
3. Add additional test cases?
