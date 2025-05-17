I'll create a similar set of configurations for infrastructure workloads, optimized for infrastructure services that need stability and high availability.

```yaml:nap/clusterpolicy/infrastructure/nodepool.yaml
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: infra-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: infra-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never  # Infrastructure nodes should be stable
    consolidateAfter: Never  # Prevent consolidation of infrastructure workloads
  template:
    metadata:
      labels:
        node-type: infrastructure
    spec:
      nodeClassRef:
        name: infra-nodes
      taints:
        - key: "workload-type"
          value: "infrastructure"
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
          values: ["D"]  # D-series for balanced performance
        - key: "karpenter.azure.com/sku-version"
          operator: In
          values: ["3"]  # v3 series for better price/performance
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ["1", "2", "3"]  # Spread across zones for HA
```

```yaml:nap/clusterpolicy/infrastructure/policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: route-infra-workloads
  annotations:
    policies.kyverno.io/title: Route Infrastructure Workloads
    policies.kyverno.io/category: Workload Distribution
    policies.kyverno.io/subject: Deployment
    policies.kyverno.io/description: >-
      This policy adds node affinity, tolerations, and topology spread constraints to route
      infrastructure workloads to infrastructure nodes with high availability.
spec:
  validationFailureAction: audit
  rules:
    - name: route-infra-workloads
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
                    - infrastructure
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
                    value: "infrastructure"
                    effect: "NoSchedule"
                +(affinity):
                  nodeAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                      nodeSelectorTerms:
                      - matchExpressions:
                        - key: node-type
                          operator: In
                          values:
                            - infrastructure
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
                +(topologySpreadConstraints):
                  - maxSkew: 1
                    topologyKey: topology.kubernetes.io/zone
                    whenUnsatisfied: ScheduleAnyway
                    labelSelector:
                      matchLabels:
                        app: "{{ request.object.spec.template.metadata.labels.app }}"
```

```yaml:nap/clusterpolicy/infrastructure/test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-infra
  labels:
    workload-type: infrastructure
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-infra-service
  namespace: test-infra
spec:
  replicas: 3  # Using 3 replicas for zone distribution
  selector:
    matchLabels:
      app: infra-service
  template:
    metadata:
      labels:
        app: infra-service
    spec:
      containers:
      - name: infra-service
        image: nginx:1.25  # Using nginx as a placeholder
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 15
```


I've created a complete infrastructure workload configuration with several key features:

1. **NodePool Configuration** (`nodepool.yaml`):
   - Uses D-series v3 VMs for balanced performance
   - On-demand instances for stability
   - Never expires or consolidates nodes
   - Multi-zone deployment for HA
   - Uses AzureLinux for the OS

2. **Kyverno Policy** (`policy.yaml`):
   - Matches namespaces labeled with `workload-type: infrastructure`
   - Adds required tolerations
   - Sets node affinity for infrastructure nodes
   - Adds pod anti-affinity for better distribution
   - Includes topology spread constraints for zone distribution
   - Precondition check for app label

3. **Test Deployment** (`test.yaml`):
   - Creates a namespace with infrastructure label
   - Deploys 3 replicas for zone distribution
   - Includes health checks (readiness/liveness probes)
   - Moderate resource requests suitable for infrastructure services
   - Proper labels for policy matching

Key differences from the high-performance configuration:
- Uses D-series instead of F-series VMs
- Adds topology spread constraints for HA
- Lower resource requests but more emphasis on reliability
- Includes health probes
- Uses 3 replicas by default for zone distribution

To test this setup:

1. Apply the NodePool and policy:
```bash
kubectl apply -f nap/clusterpolicy/infrastructure/nodepool.yaml
kubectl apply -f nap/clusterpolicy/infrastructure/policy.yaml
```

2. Deploy the test workload:
```bash
kubectl apply -f nap/clusterpolicy/infrastructure/test.yaml
```

3. Verify the deployment:
```bash
kubectl get pods -n test-infra -o wide
kubectl describe deployment -n test-infra test-infra-service
```

The deployment should:
- Get scheduled across multiple zones
- Have proper tolerations and affinity rules
- Have pods distributed for high availability

Would you like me to:
1. Add more infrastructure-specific configurations?
2. Modify the HA settings?
3. Add more test scenarios?
