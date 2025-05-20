

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

To add `privateLinkResources` to your AKS cluster config with ASO, you need to use the `apiServerAccessProfile.privateLinkResources` field in your `ManagedCluster` spec. This is an advanced AKS feature that allows you to specify which resources are exposed via Private Link.

**Example snippet:**
```yaml
spec:
  apiServerAccessProfile:
    enablePrivateCluster: true
    enablePrivateClusterPublicFQDN: false
    privateLinkResources:
      - groupId: "management"
        requiredMembers:
          - "apiServer"
      - groupId: "agent"
        requiredMembers:
          - "nodepool1"
          - "nodepool2"
```

- `groupId`: The Private Link resource group (e.g., `management`, `agent`).
- `requiredMembers`: The specific resources in that group (e.g., `apiServer`, node pool names).

**Typical usage:**
- For AKS, the most common group is `management` with member `apiServer`.
- For nodepools, use group `agent` and the nodepool names.

**Full example in context:**
```yaml
apiVersion: containerservice.azure.com/v1api20240402preview
kind: ManagedCluster
metadata:
  name: my-aks-cluster
  namespace: default
spec:
  # ... other fields ...
  apiServerAccessProfile:
    enablePrivateCluster: true
    enablePrivateClusterPublicFQDN: false
    privateLinkResources:
      - groupId: "management"
        requiredMembers:
          - "apiServer"
      - groupId: "agent"
        requiredMembers:
          - "sysnpl1"
  # ... rest of your spec ...
```

**Note:**  
- The exact structure and support may depend on the ASO version and AKS API version.  
- If you want to expose only the API server, just use the `management` group.

**References:**  
- [AKS Private Link docs](https://learn.microsoft.com/en-us/azure/aks/private-link)
- [AKS API reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-arm-template#apiserveraccessprofile-object)

Let me know if you want a patch for your current YAML.
