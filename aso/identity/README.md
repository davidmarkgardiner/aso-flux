# Azure Managed Identity Setup with ASO

This directory contains the configuration for setting up a managed identity with federated credentials for workload identity in AKS.

## Files
- `managedidentity.yaml`: Defines the User Assigned Managed Identity
- `federated.yaml`: Defines the federated credential for workload identity
- `configmap.yaml`: Contains the identity details (needs to be created)
- `secret.yaml`: Contains sensitive identity details (needs to be created)

## Setup Process

1. **Create the Managed Identity**
   ```bash
   kubectl apply -f managedidentity.yaml
   ```
   This creates a User Assigned Managed Identity in Azure. The identity details (clientId, principalId, tenantId) will be stored in a ConfigMap and Secret.

2. **Get Identity Details**
   After the identity is created, get its details:
   ```bash
   # Get the identity details from Azure
   az identity show --name sampleuserassignedidentity --resource-group aso-sample-rg --query '{clientId:clientId,principalId:principalId,tenantId:tenantId}' -o json
   ```

3. **Create ConfigMap and Secret**
   Create `configmap.yaml`:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: umi-cm
     namespace: default
   data:
     clientId: "<client-id-from-azure>"
     principalId: "<principal-id-from-azure>"
     tenantId: "<tenant-id-from-azure>"
   ```

   Create `secret.yaml`:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: umi-secret
     namespace: default
   type: Opaque
   stringData:
     clientId: "<client-id-from-azure>"
     principalId: "<principal-id-from-azure>"
     tenantId: "<tenant-id-from-azure>"
   ```

4. **Create Federated Credential**
   ```bash
   kubectl apply -f federated.yaml
   ```
   This creates a federated credential that allows the Kubernetes service account to authenticate as the managed identity.

## Important Notes

1. **OIDC Issuer URL**
   - The `issuer` in `federated.yaml` must match your AKS cluster's OIDC issuer URL
   - Get it with: `az aks show -n <cluster-name> -g <resource-group> --query "oidcIssuerProfile.issuerUrl" -o tsv`
   - Update the URL in `federated.yaml` accordingly

2. **Service Account**
   - The `subject` in `federated.yaml` must match your service account
   - Format: `system:serviceaccount:<namespace>:<serviceaccount-name>`
   - Create the service account if it doesn't exist:
     ```yaml
     apiVersion: v1
     kind: ServiceAccount
     metadata:
       name: default
       namespace: default
       annotations:
         azure.workload.identity/client-id: "<client-id-from-azure>"
     ```

3. **Audience**
   - For workload identity, always use `api://AzureADTokenExchange`

## Usage

To use this identity in a pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: default
spec:
  serviceAccountName: default  # The service account with workload identity
  containers:
  - name: my-container
    image: my-image
    env:
    - name: AZURE_CLIENT_ID
      valueFrom:
        configMapKeyRef:
          name: umi-cm
          key: clientId
    - name: AZURE_TENANT_ID
      valueFrom:
        configMapKeyRef:
          name: umi-cm
          key: tenantId
```

## Troubleshooting

1. **Check Identity Status**
   ```bash
   kubectl get userassignedidentity sampleuserassignedidentity -n default
   kubectl get federatedidentitycredential aso-fic -n default
   ```

2. **Verify Service Account**
   ```bash
   kubectl get serviceaccount default -n default -o yaml
   ```

3. **Check Pod Identity**
   ```bash
   kubectl describe pod <pod-name> -n default
   ```

4. **Test Authentication**
   ```bash
   # Inside the pod
   curl -H "Authorization: Bearer $(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -H Metadata:true | jq -r .access_token)" https://management.azure.com/subscriptions/<subscription-id>?api-version=2020-01-01
   ``` 