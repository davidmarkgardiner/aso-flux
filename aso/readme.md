

Here's your env file (`aso/cluster.env`) with all the variables from your ConfigMap, ready for use with `envsubst` or `sed` for template replacement.

If you want a one-liner to replace variables in your template:
```sh
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```
or with sed (for ${VAR} style):
```sh
set -a; source aso/cluster.env; set +a
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```

Let me know if you want a script for batch replacement or more automation.

If you use `envsubst`, you do **not** need to source the env file—just run:
```sh
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```
as long as you export the variables in your current shell, or use `envsubst` with variables set inline.

If you want to use the variables in your shell (e.g., for `sed` or other scripts), you should source the env file:
```sh
set -a
source aso/cluster.env
set +a
```
This exports all variables in the file to your environment.

**Summary:**  
- For `envsubst`, you can either export variables or source the file.
- For `sed` or shell scripts that use `$VAR`, you must source the env file so the variables are available.

If you want a pure one-liner for `envsubst`:
```sh
set -a; source aso/cluster.env; set +a; envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```

If you just want to replace in-place with `sed`, you must source the env file first.

---
Perfect, you’re quoting the official ASO/AKS CRD schema for `privateLinkResources`. Here’s how you’d add a `privateLinkResources` block to your `ManagedCluster` spec, using all the available fields:

```yaml
spec:
  apiServerAccessProfile:
    enablePrivateCluster: true
    enablePrivateClusterPublicFQDN: false
  privateLinkResources:
    - groupId: management
      name: management
      reference:
        armId: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME}/privateLinkResources/management
      requiredMembers:
        - apiServer
      type: Microsoft.ContainerService/managedClusters/privateLinkResources
    - groupId: agent
      name: sysnpl1
      reference:
        armId: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME}/privateLinkResources/agent
      requiredMembers:
        - sysnpl1
      type: Microsoft.ContainerService/managedClusters/privateLinkResources
```

**Key points:**
- `groupId`: e.g., `management` or `agent`
- `name`: name of the private link resource (e.g., `management`, node pool name)
- `reference.armId`: ARM ID of the private link resource (template with your variables)
- `requiredMembers`: array of required members (e.g., `apiServer`, node pool names)
- `type`: always `Microsoft.ContainerService/managedClusters/privateLinkResources` for AKS

**You can omit fields you don’t need** (they’re all optional), but this is the most explicit form.

**Minimal example:**
```yaml
privateLinkResources:
  - groupId: management
    requiredMembers:
      - apiServer
  - groupId: agent
    requiredMembers:
      - sysnpl1
```

**Plug this under your `spec:` in the cluster manifest.**  
Let me know if you want a patch for your actual YAML.
