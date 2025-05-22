# Azure Managed Identities Setup for Kubernetes Services

This directory contains the configuration for setting up managed identities with federated credentials for:
- External Secrets Operator (ESO)
- External DNS
- Cert Manager

## Files
- `managedidentity.yaml`: Defines the User Assigned Managed Identities (ASO will create these in Azure)
- `federated.yaml`: Defines the federated credentials for workload identity
- `configmap.yaml`: Will be automatically populated by ASO with identity details
- `serviceaccounts.yaml`: Defines the service accounts for each service

## Setup Process

1. **Create the Managed Identities**
   ```bash
   kubectl apply -f managedidentity.yaml
   ```
   This creates three User Assigned Managed Identities in Azure via ASO:
   - `eso-identity` for External Secrets Operator
   - `external-dns-identity` for External DNS
   - `cert-manager-identity` for Cert Manager

   ASO will automatically create and populate the ConfigMaps with the identity details.

2. **Verify Identity Creation**
   ```bash
   # Check if identities are created
   kubectl get userassignedidentity -n default

   # Check if ConfigMaps are populated
   kubectl get configmap eso-identity-cm -n default -o yaml
   kubectl get configmap external-dns-identity-cm -n default -o yaml
   kubectl get configmap cert-manager-identity-cm -n default -o yaml
   ```

3. **Update Service Accounts**
   After the ConfigMaps are populated, update `serviceaccounts.yaml` with the client IDs:
   ```bash
   # Get the client IDs
   ESO_CLIENT_ID=$(kubectl get configmap eso-identity-cm -n default -o jsonpath='{.data.clientId}')
   DNS_CLIENT_ID=$(kubectl get configmap external-dns-identity-cm -n default -o jsonpath='{.data.clientId}')
   CERT_CLIENT_ID=$(kubectl get configmap cert-manager-identity-cm -n default -o jsonpath='{.data.clientId}')

   # Update serviceaccounts.yaml with these values
   ```

4. **Create Namespaces and Service Accounts**
   ```bash
   # Create namespaces
   kubectl create namespace external-secrets
   kubectl create namespace external-dns
   kubectl create namespace cert-manager

   # Apply service accounts
   kubectl apply -f serviceaccounts.yaml
   ```

5. **Update Federated Credentials**
   - Get your cluster's OIDC issuer URL:
     ```bash
     az aks show -n <cluster-name> -g <resource-group> --query "oidcIssuerProfile.issuerUrl" -o tsv
     ```
   - Update the `issuer` URL in `federated.yaml` for all three federated credentials

6. **Create Federated Credentials**
   ```bash
   kubectl apply -f federated.yaml
   ```

## Required Azure RBAC Permissions

1. **External Secrets Operator Identity**
   - Key Vault Secrets User on target key vaults
   - Key Vault Reader on target key vaults

2. **External DNS Identity**
   - DNS Zone Contributor on target DNS zones
   - Reader on resource groups containing DNS zones

3. **Cert Manager Identity**
   - DNS Zone Contributor on target DNS zones
   - Key Vault Certificates Officer on target key vaults
   - Key Vault Secrets Officer on target key vaults

Assign these roles using the principal IDs from the ConfigMaps:
```bash
# Get principal IDs from ConfigMaps
ESO_PRINCIPAL_ID=$(kubectl get configmap eso-identity-cm -n default -o jsonpath='{.data.principalId}')
DNS_PRINCIPAL_ID=$(kubectl get configmap external-dns-identity-cm -n default -o jsonpath='{.data.principalId}')
CERT_PRINCIPAL_ID=$(kubectl get configmap cert-manager-identity-cm -n default -o jsonpath='{.data.principalId}')

# For ESO
az role assignment create --role "Key Vault Secrets User" --assignee-object-id $ESO_PRINCIPAL_ID --scope <key-vault-resource-id>
az role assignment create --role "Key Vault Reader" --assignee-object-id $ESO_PRINCIPAL_ID --scope <key-vault-resource-id>

# For External DNS
az role assignment create --role "DNS Zone Contributor" --assignee-object-id $DNS_PRINCIPAL_ID --scope <dns-zone-resource-id>
az role assignment create --role "Reader" --assignee-object-id $DNS_PRINCIPAL_ID --scope <resource-group-id>

# For Cert Manager
az role assignment create --role "DNS Zone Contributor" --assignee-object-id $CERT_PRINCIPAL_ID --scope <dns-zone-resource-id>
az role assignment create --role "Key Vault Certificates Officer" --assignee-object-id $CERT_PRINCIPAL_ID --scope <key-vault-resource-id>
az role assignment create --role "Key Vault Secrets Officer" --assignee-object-id $CERT_PRINCIPAL_ID --scope <key-vault-resource-id>
```

## Troubleshooting

1. **Check Identity Status**
   ```bash
   kubectl get userassignedidentity -n default
   kubectl get federatedidentitycredential -n default
   ```

2. **Verify Service Accounts**
   ```bash
   kubectl get serviceaccount -n external-secrets external-secrets -o yaml
   kubectl get serviceaccount -n external-dns external-dns -o yaml
   kubectl get serviceaccount -n cert-manager cert-manager -o yaml
   ```

3. **Test Authentication**
   ```bash
   # Inside a pod using any of the service accounts
   curl -H "Authorization: Bearer $(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -H Metadata:true | jq -r .access_token)" https://management.azure.com/subscriptions/<subscription-id>?api-version=2020-01-01
   ``` 