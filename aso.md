TITLE: Create Azure Resource Group with ASO
DESCRIPTION: Applies a YAML manifest using kubectl to create an Azure Resource Group named 'aso-sample-rg' in the 'westcentralus' region via the Azure Service Operator.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_13

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: resources.azure.com/v1alpha1api20200601
kind: ResourceGroup
metadata:
  name: aso-sample-rg
  namespace: default
spec:
  location: westcentralus
EOF
```

----------------------------------------

TITLE: Create Azure Service Principal for ASO
DESCRIPTION: This command creates an Azure Service Principal with the 'Contributor' role scoped to your subscription. This identity will be used by ASO to create and manage Azure resources. A more restricted scope can be used if desired.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_6

LANGUAGE: bash
CODE:
```
az ad sp create-for-rbac -n azure-service-operator --role contributor \
    --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID
```

LANGUAGE: powershell
CODE:
```
az ad sp create-for-rbac -n azure-service-operator --role contributor \`
    --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID
```

LANGUAGE: cmd
CODE:
```
az ad sp create-for-rbac -n azure-service-operator --role contributor ^
    --scopes /subscriptions/%AZURE_SUBSCRIPTION_ID%
```

----------------------------------------

TITLE: Install/Upgrade ASO v2 Helm Chart (Bash)
DESCRIPTION: Adds the Azure Service Operator v2 Helm repository and installs or upgrades the operator into the 'azureserviceoperator-system' namespace. Configures the operator to watch specific CRD groups using the 'crdPattern' parameter. Note the use of single quotes (') for 'crdPattern' to prevent wildcard expansion in bash.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_2

LANGUAGE: bash
CODE:
```
$ helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
$ helm upgrade --install aso2 aso2/azure-service-operator \
    --create-namespace \
    --namespace=azureserviceoperator-system \
    --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*'
```

----------------------------------------

TITLE: Creating Resource with Resource-Specific Secret (Resource) - Bash
DESCRIPTION: Creates an Azure ResourceGroup custom resource using kubectl apply, demonstrating how to reference a resource-specific credential secret (`my-resource-secret`) using the `serviceoperator.azure.com/credential-from` annotation for authentication.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_39

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -\napiVersion: resources.azure.com/v1api20200601\nkind: ResourceGroup\nmetadata:\n  name: aso-sample-rg\n  namespace: default\n  annotations:\n    serviceoperator.azure.com/credential-from: my-resource-secret\nspec:\n  location: westcentralus\nEOF
```

----------------------------------------

TITLE: Upgrading ASO using Helm
DESCRIPTION: This snippet demonstrates how to upgrade Azure Service Operator using Helm. It involves adding the ASO v2 chart repository, updating the local repository list, and then running the helm upgrade command with the desired version and necessary Azure credentials.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/upgrading.md#_snippet_0

LANGUAGE: bash
CODE:
```
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update
helm upgrade --version v2.0.0 aso2 aso2/azure-service-operator \
        --namespace=azureserviceoperator-system \
        --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
        --set azureTenantID=$AZURE_TENANT_ID \
        --set azureClientID=$AZURE_CLIENT_ID \
        --set azureClientSecret=$AZURE_CLIENT_SECRET
```

----------------------------------------

TITLE: Azure ResourceGroup Custom Resource YAML
DESCRIPTION: Defines the YAML content for a Kubernetes Custom Resource of kind `ResourceGroup` managed by ASO. This definition specifies the desired state for an Azure Resource Group named `aso-sample-rg` in the `default` namespace, located in the `westcentralus` Azure region.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_14

LANGUAGE: yaml
CODE:
```
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: aso-sample-rg
  namespace: default
spec:
  location: westcentralus
```

----------------------------------------

TITLE: Install ASO Globally with Workload Identity (Helm)
DESCRIPTION: Installs or upgrades Azure Service Operator (ASO) globally using Helm, configuring it for workload identity authentication. Sets subscription, tenant, client IDs, enables workload identity, and specifies CRD patterns. Requires Helm and access to the ASO Helm chart.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_3

LANGUAGE: bash
CODE:
```
helm upgrade --install --devel aso2 aso2/azure-service-operator \
        --create-namespace \
        --namespace=azureserviceoperator-system \
        --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
        --set azureTenantID=$AZURE_TENANT_ID \
        --set azureClientID=$AZURE_CLIENT_ID \
        --set useWorkloadIdentityAuth=true \
        --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*'
```

----------------------------------------

TITLE: Checking ASO Resource Status (kubectl)
DESCRIPTION: Use `kubectl get` for an ASO-managed custom resource (like `resourcegroups.resources.azure.com`) to check its status. A `READY: False` status with `REASON: Reconciling` indicates the operator is actively processing the resource.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/diagnosing-problems/_index.md#_snippet_4

LANGUAGE: shell
CODE:
```
$ kubectl get resourcegroups.resources.azure.com
NAME            READY     SEVERITY   REASON          MESSAGE
aso-sample-rg   False     Info       Reconciling     The resource is in the process of being reconciled by the operator
```

----------------------------------------

TITLE: Set Azure Tenant and Subscription IDs
DESCRIPTION: Sets environment variables for your Azure Tenant ID and Subscription ID. These are required for creating the Service Principal and installing ASO.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_4

LANGUAGE: yaml
CODE:
```
AZURE_TENANT_ID=<your-tenant-id-goes-here>
AZURE_SUBSCRIPTION_ID=<your-subscription-id-goes-here>
```

----------------------------------------

TITLE: Describe Azure Resource Group with ASO using Kubectl
DESCRIPTION: Use the `kubectl describe` command to view the details and status of an Azure Resource Group resource managed by Azure Service Operator (ASO) within your Kubernetes cluster. This command provides information about the resource's specification, status, and events.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_14

LANGUAGE: bash
CODE:
```
kubectl describe resourcegroups/aso-sample-rg
```

----------------------------------------

TITLE: Apply Azure ResourceGroup Custom Resource (Bash)
DESCRIPTION: Applies the `rg.yaml` file to the Kubernetes cluster using `kubectl apply`. This command instructs Azure Service Operator to create or update the corresponding Azure Resource Group based on the definition in the file.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_15

LANGUAGE: bash
CODE:
```
$ kubectl apply -f rg.yaml
```

----------------------------------------

TITLE: Exporting Azure Resource Secrets using secrets (YAML)
DESCRIPTION: Illustrates how to use the `.spec.operatorSpec.secrets` field to extract specific secrets directly from an Azure resource's status (like Cosmos DB keys and endpoint) and write them to specified keys within Kubernetes Secrets.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/secrets.md#_snippet_2

LANGUAGE: yaml
CODE:
```
apiVersion: documentdb.azure.com/v1alpha1api20210515
kind: DatabaseAccount
metadata:
  name: sample-db-account
  namespace: default
spec:
  location: westcentralus
  owner:
    name: aso-sample-rg
  kind: MongoDB
  databaseAccountOfferType: Standard
  locations:
    - locationName: westcentralus
  operatorSpec:
    secrets:
      primaryMasterKey:
        name: mysecret
        key: primarymasterkey
      secondaryMasterKey:
        name: mysecret
        key: secondarymasterkey
      documentEndpoint: # Can put different secrets into different Kubernetes secrets, if desired
        name: myendpoint
        key: endpoint
```

----------------------------------------

TITLE: Install ASO Globally with Helm (Bash)
DESCRIPTION: Installs or upgrades Azure Service Operator globally using Helm, setting Azure credentials and CRD patterns via command-line arguments. This method is suitable for initial installations.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_9

LANGUAGE: bash
CODE:
```
helm upgrade --install --devel aso2 aso2/azure-service-operator \
        --create-namespace \
        --namespace=azureserviceoperator-system \
        --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
        --set azureTenantID=$AZURE_TENANT_ID \
        --set azureClientID=$AZURE_CLIENT_ID \
        --set azureClientSecret=$AZURE_CLIENT_SECRET \
        --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*'
```

----------------------------------------

TITLE: Install/Upgrade ASO v2 Helm Chart (PowerShell)
DESCRIPTION: Adds the Azure Service Operator v2 Helm repository and installs or upgrades the operator into the 'azureserviceoperator-system' namespace. Configures the operator to watch specific CRD groups using the 'crdPattern' parameter. Uses the backtick (`) for line continuation in PowerShell.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_3

LANGUAGE: powershell
CODE:
```
PS> helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
PS> helm upgrade --install aso2 aso2/azure-service-operator `
    --create-namespace `
    --namespace=azureserviceoperator-system `
    --set crdPattern=resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*
```

----------------------------------------

TITLE: Install ASO Operator via asoctl Template Export (Bash)
DESCRIPTION: Exports the Azure Service Operator v2 deployment template using asoctl, filtering CRDs based on the provided pattern, and applies the resulting YAML directly to the Kubernetes cluster using kubectl. Requires asoctl and kubectl to be installed and configured. The --crd-pattern flag is crucial for selecting required CRDs.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/installing-from-yaml.md#_snippet_0

LANGUAGE: Bash
CODE:
```
asoctl export template --version v2.6.0 --crd-pattern "<your pattern>" | kubectl apply -f -
```

----------------------------------------

TITLE: Configure Service Principal Federated Credential (Bash)
DESCRIPTION: Retrieves the object ID for a Service Principal using its client ID, creates a JSON parameter file, and then creates a federated identity credential in Azure AD using the Azure CLI. This links the Kubernetes service account to the Service Principal for authentication via Workload Identity.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_2

LANGUAGE: bash
CODE:
```
export APPLICATION_OBJECT_ID="$(az ad app show --id ${AZURE_CLIENT_ID} --query id -otsv)"
```

LANGUAGE: bash
CODE:
```
cat <<EOF > params.json
{
  "name": "aso-federated-credential",
  "issuer": "${SERVICE_ACCOUNT_ISSUER}",
  "subject": "system:serviceaccount:azureserviceoperator-system:azureserviceoperator-default",
  "description": "Kubernetes service account federated credential",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF
```

LANGUAGE: bash
CODE:
```
az ad app federated-credential create --id ${APPLICATION_OBJECT_ID} --parameters @params.json
```

----------------------------------------

TITLE: Create Global aso-controller-settings Secret (Bash/YAML)
DESCRIPTION: Provides a bash script using `kubectl apply` to create or update the global `aso-controller-settings` Kubernetes Secret in the `azureserviceoperator-system` namespace, containing essential Azure credentials.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_23

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
 name: aso-controller-settings
 namespace: azureserviceoperator-system
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$IDENTITY_CLIENT_ID"
EOF
```

----------------------------------------

TITLE: Create Operator Namespace (kubectl/bash)
DESCRIPTION: Creates the Kubernetes namespace azureserviceoperator-system where the ASO operator components will be installed.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/contributing/create-a-new-release.md#_snippet_7

LANGUAGE: bash
CODE:
```
kubectl create namespace azureserviceoperator-system
```

----------------------------------------

TITLE: Example Usage of Generic Resource Reference in RoleAssignment (YAML)
DESCRIPTION: Demonstrates how the generic resource reference mechanism is used in a YAML definition for an Azure RoleAssignment. Shows referencing the `status.principalId` property of a UserAssignedIdentity resource by name, group, and kind.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/ADR-2022-09-Reading-Status-Properties-Of-Resources.md#_snippet_5

LANGUAGE: yaml
CODE:
```
apiVersion: managedidentity.azure.com/v1beta20181130
kind: UserAssignedIdentity
metadata:
  name: sample-uai
spec:
  location: Germany West Central
  owner:
    name: dev-sample-rg
---
apiVersion: authorization.azure.com/v1beta20200801preview
kind: RoleAssignment
metadata:
  name: 6a2d44f5-57d8-4916-9f46-ff7c9c1b338f
spec:
  location: Germany West Central
  owner:
    name: samplevnet
    group: network.azure.com
    kind: VirtualNetwork
  principalId:
    ref:
      name: sample-uai  # Can pull any arbitrary property from another ASO resource.
      group: manangedidentity.azure.com
      kind: UserAssignedIdentity
      path: status.principalId  # In this case, getting status.principalId
  roleDefinitionReference:
    armId: /subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c
```

----------------------------------------

TITLE: View all ASOv2 resources using kubectl
DESCRIPTION: Lists all Kubernetes resources managed by Azure Service Operator v2 across all namespaces. It pipes the output of `kubectl api-resources` to filter for ASOv2 resources and then uses `xargs` to get details for each found resource type.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/asov1-asov2-migration/_index.md#_snippet_9

LANGUAGE: sh
CODE:
```
kubectl api-resources -o name | grep azure.com | paste -sd "," - | xargs kubectl get -A
```

----------------------------------------

TITLE: Exporting Azure Resource Secrets using secretExpressions (YAML)
DESCRIPTION: Shows how to use the `.spec.operatorSpec.secretExpressions` field to extract specific values from an Azure resource's status (like Cosmos DB keys and endpoint) using expressions and write them to specified keys within Kubernetes Secrets.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/secrets.md#_snippet_1

LANGUAGE: yaml
CODE:
```
apiVersion: documentdb.azure.com/v1alpha1api20210515
kind: DatabaseAccount
metadata:
  name: sample-db-account
  namespace: default
spec:
  location: westcentralus
  owner:
    name: aso-sample-rg
  kind: MongoDB
  databaseAccountOfferType: Standard
  locations:
    - locationName: westcentralus
  operatorSpec:
    secretExpressions:
      - name: mysecret
        key: primarymasterkey
        value: secret.primaryMasterKey
      - name: mysecret
        key: secondarymasterkey
        value: secret.secondaryMasterKey
      - name: myendpoint  # Can put different values into different Kubernetes secrets, if desired
        key: endpoint
        value: self.status.documentEndpoint
```

----------------------------------------

TITLE: Configuring ASO Secrets with KeyVault and Multiple Destinations (YAML)
DESCRIPTION: This YAML snippet shows a complex configuration for Azure Service Operator (ASO) secrets. It illustrates how to define multiple secret destinations for a single resource (like CosmosDB), including referencing secrets stored in Azure Key Vault and standard Kubernetes Secrets. It specifies different keys (primaryKey, secondaryKey, readOnlyPrimaryKey, readOnlySecondaryKey, endpoint) and their respective types (KeyVault, Secret) and destinations (name, key).
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/secrets.md#_snippet_4

LANGUAGE: yaml
CODE:
```
spec:
  # Other spec fields elided...
  operatorSpec:
    secrets:
      primaryKey:
        type: KeyVault
        reference:
          armId: /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/asokeyvault
        name: my-primary-key
      secondaryKey:
        type: KeyVault
        reference:
          armId: /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/asokeyvault
        name: my-secondary-key
      readOnlyPrimaryKey:
        type: Secret
        name: my-readonly-secret
        key: PRIMARY_KEY
      readOnlySecondaryKey:
        type: Secret
        name: my-readonly-secret
        key: SECONDARY_KEY
      endpoint:
        type: Secret
        name: my-secret
        key: ENDPOINT
```

----------------------------------------

TITLE: Exporting ASO UserAssignedIdentity Status to ConfigMap (configMaps) (YAML)
DESCRIPTION: Illustrates using `operatorSpec.configMaps` in an Azure Service Operator `UserAssignedIdentity` resource to export the `principalId` and `clientId` status fields to a Kubernetes `ConfigMap` named `identity-settings`. This is a direct mapping approach for exporting status data.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/configmaps.md#_snippet_2

LANGUAGE: YAML
CODE:
```
apiVersion: managedidentity.azure.com/v1api20181130
kind: UserAssignedIdentity
metadata:
  name: sampleuserassignedidentity
  namespace: default
spec:
  location: westcentralus
  owner:
    name: aso-sample-rg
  operatorSpec:
    configMaps:
      # Export the principalId and clientId to a ConfigMap for use by our application and/or
      # other ASO resources such as RoleAssignments
      principalId:
        name: identity-settings
        key: principalId
      clientId:
        name: identity-settings
        key: clientId
```

----------------------------------------

TITLE: Install or Upgrade Azure Service Operator with Helm
DESCRIPTION: Installs or upgrades the Azure Service Operator v2 Helm chart, configuring it with the Azure credentials and specifying which CRDs to install using the crdPattern.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_9

LANGUAGE: bash
CODE:
```
helm upgrade --install aso2 aso2/azure-service-operator \
     --create-namespace \
     --namespace=azureserviceoperator-system \
     --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
     --set azureTenantID=$AZURE_TENANT_ID \
     --set azureClientID=$AZURE_CLIENT_ID \
     --set azureClientSecret=$AZURE_CLIENT_SECRET \
     --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*'
```

----------------------------------------

TITLE: Getting Resource Status with kubectl
DESCRIPTION: This snippet shows how to use the `kubectl get` command to view the status conditions of an Azure Service Operator resource, specifically a ResourceGroup. It displays the `NAME`, `READY`, `SEVERITY`, `REASON`, and `MESSAGE` columns which provide details about the resource's current state and reconciliation status.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/conditions.md#_snippet_0

LANGUAGE: shell
CODE:
```
$ kubectl get resourcegroups.resources.azure.com
NAME            READY     SEVERITY   REASON          MESSAGE
aso-sample-rg   False     Info       Reconciling     The resource is in the process of being reconciled by the operator
```

----------------------------------------

TITLE: Set Azure Tenant and Subscription IDs Environment Variables
DESCRIPTION: These commands set the environment variables required to identify your Azure tenant and subscription. These values are necessary for subsequent Azure CLI commands to operate within the correct context.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_5

LANGUAGE: bash
CODE:
```
export AZURE_TENANT_ID=<your-tenant-id-goes-here>
export AZURE_SUBSCRIPTION_ID=<your-subscription-id-goes-here>
```

LANGUAGE: powershell
CODE:
```
$AZURE_TENANT_ID=<your-tenant-id-goes-here>
$AZURE_SUBSCRIPTION_ID=<your-subscription-id-goes-here>
```

LANGUAGE: cmd
CODE:
```
SET AZURE_TENANT_ID=<your-tenant-id-goes-here>
SET AZURE_SUBSCRIPTION_ID=<your-subscription-id-goes-here>
```

----------------------------------------

TITLE: Create ASO Global Authentication Secret (Bash/YAML)
DESCRIPTION: Creates a Kubernetes Secret named aso-controller-settings in the azureserviceoperator-system namespace. This secret stores the Azure credentials (Subscription ID, Tenant ID, Client ID, Client Secret) required by the operator, read from environment variables. Requires kubectl and the environment variables to be set.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/installing-from-yaml.md#_snippet_1

LANGUAGE: Bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aso-controller-settings
  namespace: azureserviceoperator-system
stringData:
  AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
  AZURE_TENANT_ID: "$AZURE_TENANT_ID"
  AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
  AZURE_CLIENT_SECRET: "$AZURE_CLIENT_SECRET"
EOF
```

----------------------------------------

TITLE: Create Namespace-Scoped ASO Credential Secret (kubectl)
DESCRIPTION: Creates a Kubernetes secret named `aso-credential` in a specific namespace (`my-namespace` in the example). This secret holds Azure credentials (subscription, tenant, client IDs) for ASO resources deployed within that namespace using workload identity. Requires kubectl access to the cluster.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_5

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
 name: aso-credential
 namespace: my-namespace
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID:    "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID:    "$AZURE_CLIENT_ID"
EOF
```

----------------------------------------

TITLE: Delete Azure Resource Group with ASO using Kubectl
DESCRIPTION: Execute the `kubectl delete` command to remove an Azure Resource Group resource managed by Azure Service Operator (ASO) from your Kubernetes cluster. ASO will then initiate the deletion of the corresponding resource in Azure. Be aware that deleting a Resource Group in Azure will delete all resources contained within it.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_15

LANGUAGE: bash
CODE:
```
kubectl delete resourcegroups/aso-sample-rg
```

----------------------------------------

TITLE: Decoding Azure Operator Settings Secret
DESCRIPTION: Retrieve and decode the `azureoperatorsettings` secret in the `operators` namespace using `kubectl` with a Go template. This command helps inspect the secret contents, such as the service principal credentials, locally for troubleshooting.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/troubleshooting.md#_snippet_3

LANGUAGE: Bash
CODE:
```
kubectl get secret azureoperatorsettings -n operators -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"
"}}{{end}}'
```

----------------------------------------

TITLE: Referencing Kubernetes Secret for MySQL Admin Password (YAML)
DESCRIPTION: Demonstrates how to configure an Azure Database for MySQL Flexible Server resource in ASO, referencing a Kubernetes Secret for the administrator password using the `administratorLoginPassword` field. This field uses a SecretReference to specify the secret name and key.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/secrets.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: dbformysql.azure.com/v1api20230630
kind: FlexibleServer
metadata:
  name: samplemysql
  namespace: default
spec:
  location: eastus
  owner:
    name: aso-sample-rg
  version: "8.0.21"
  sku:
    name: Standard_D4ds_v4
    tier: GeneralPurpose
  administratorLogin: myAdmin
  administratorLoginPassword: # This is the name/key of a Kubernetes secret in the same namespace
    name: server-admin-pw
    key: password
  storage:
    storageSizeGB: 128
```

----------------------------------------

TITLE: Create Azure Service Principal for ASO
DESCRIPTION: Creates an Azure Active Directory Service Principal with 'Contributor' role scoped to the specified subscription. This principal is used by ASO to manage Azure resources.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_5

LANGUAGE: bash
CODE:
```
az ad sp create-for-rbac -n azure-service-operator --role contributor \
    --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID
```

----------------------------------------

TITLE: Importing Azure Resources using asoctl
DESCRIPTION: Use the asoctl import azure-resource command to export resources from a specific Azure resource group into a YAML file. The command includes options to specify the output file, target Kubernetes namespace, and add annotations like the 'skip' reconcile policy.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/asov1-asov2-migration/_index.md#_snippet_3

LANGUAGE: shell
CODE:
```
asoctl import azure-resource /subscriptions/<subid>/resourceGroups/<rg> -o resources.yaml -namespace <namespace> -annotation serviceoperator.azure.com/reconcile-policy=skip
```

----------------------------------------

TITLE: Defining Azure Custom Role for ASO (JSON)
DESCRIPTION: This JSON defines a custom Azure role named 'ASO Operator' intended for use with Azure Service Operator (ASO). It grants specific permissions ('*' for read, write, delete, action) to manage Resource Groups, Azure Cache (Redis), and Azure Database for MySQL Flexible Servers within specified subscriptions. This role can be used instead of the broad Contributor role to limit ASO's access.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/reducing-access.md#_snippet_0

LANGUAGE: JSON
CODE:
```
{
  "Name": "ASO Operator",
  "IsCustom": true,
  "Description": "Role with access to perform only the operations which we allow ASO to perform",
  "Actions": [
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Cache/*",
    "Microsoft.DBforMySQL/*"
  ],
  "NotActions": [
  ],
  "AssignableScopes": [
    "/subscriptions/{subscriptionId1}",
    "/subscriptions/{subscriptionId2}"
  ]
}
```

----------------------------------------

TITLE: Check Kubernetes Cluster Version (kubectl)
DESCRIPTION: This command is used to check the version of your currently connected Kubernetes cluster. ASO v2 requires a cluster version of at least 1.16. This is a necessary prerequisite step before installing and using ASO.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/v2/README.md#_snippet_0

LANGUAGE: bash
CODE:
```
kubectl version
```

----------------------------------------

TITLE: Specifying Owner by Name in YAML
DESCRIPTION: Demonstrates how a user specifies the owner of a dependent resource in the Kubernetes YAML manifest. The `owner` field uses a `name` reference to point to the owning resource (e.g., a Virtual Network named `my-vnet`).
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/type-references-and-ownership.md#_snippet_8

LANGUAGE: yaml
CODE:
```
...
  spec:
    owner:
      name: my-vnet
...
```

----------------------------------------

TITLE: Set Azure Service Principal Credentials Environment Variables
DESCRIPTION: These commands set the environment variables for the Service Principal's client ID (appId) and client secret (password). ASO uses these credentials to authenticate with Azure.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/_index.md#_snippet_7

LANGUAGE: bash
CODE:
```
export AZURE_CLIENT_ID=<your-client-id>         # This is the appID from the service principal we created.
export AZURE_CLIENT_SECRET=<your-client-secret> # This is the password from the service principal we created.
```

LANGUAGE: powershell
CODE:
```
$AZURE_CLIENT_ID=<your-client-id>         # This is the appID from the service principal we created.
$AZURE_CLIENT_SECRET=<your-client-secret> # This is the password from the service principal we created.
```

LANGUAGE: cmd
CODE:
```
:: This is the appID from the service principal we created.
SET AZURE_CLIENT_ID=<your-client-id>         
:: This is the password from the service principal we created.
SET AZURE_CLIENT_SECRET=<your-client-secret>
```

----------------------------------------

TITLE: Annotate Resource to Skip Reconciliation (YAML)
DESCRIPTION: Apply this annotation to the Kubernetes resource spec or metadata to instruct Azure Service Operator to skip reconciliation. This is crucial before deleting the resource from Kubernetes to prevent ASO from deleting the corresponding Azure resource.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/breaking-changes/breaking-changes-v2.6.0.md#_snippet_0

LANGUAGE: yaml
CODE:
```
serviceoperator.azure.com/reconcile-policy: skip
```

----------------------------------------

TITLE: Install ASO with asoctl (asoctl/kubectl/bash)
DESCRIPTION: Uses asoctl to export the installation template for a specific ASO version (v2.7.0), filtering for specific CRDs, and pipes the output directly to kubectl apply -f - to install ASO into the cluster.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/contributing/create-a-new-release.md#_snippet_10

LANGUAGE: bash
CODE:
```
./asoctl export template --version v2.7.0 --crd-pattern "resources.azure.com/*;network.azure.com/*" | kubectl apply -f -
```

----------------------------------------

TITLE: Inspecting ASO Controller Pod Events (kubectl)
DESCRIPTION: Use `kubectl describe pod` with a selector to view detailed events for the ASO controller pod. Look for events like `Error: secret "aso-controller-settings" not found` to diagnose configuration errors.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/diagnosing-problems/_index.md#_snippet_1

LANGUAGE: text
CODE:
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  ...
  Warning  Failed     36s (x7 over 99s)  kubelet            Error: secret "aso-controller-settings" not found
  ...
```

----------------------------------------

TITLE: Set Azure Service Principal Environment Variables (Bash)
DESCRIPTION: Sets environment variables (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`) in the current Bash session. These variables are typically used to configure tools or scripts that interact with Azure, including potentially setting up credentials for ASO secrets when using client secret authentication.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_8

LANGUAGE: bash
CODE:
```
export AZURE_CLIENT_ID="00000000-0000-0000-0000-00000000000"       # The client ID (sometimes called App Id) of the Service Principal.
export AZURE_CLIENT_SECRET="00000000-0000-0000-0000-00000000000"   # The client secret of the Service Principal.
export AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-00000000000" # The Azure Subscription ID the identity is in.
export AZURE_TENANT_ID="00000000-0000-0000-0000-00000000000"       # The Azure AAD Tenant the identity/subscription is associated with.
```

----------------------------------------

TITLE: Set Workload Identity Environment Variables (Bash)
DESCRIPTION: Sets essential environment variables (Client ID, Subscription ID, Tenant ID, OIDC Issuer) required for configuring Workload Identity authentication with Azure Service Operator. Customize the placeholder values with your specific Azure and cluster details.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_0

LANGUAGE: bash
CODE:
```
export AZURE_CLIENT_ID="00000000-0000-0000-0000-00000000000"       # The client ID (sometimes called App Id) of the Service Principal, or the Client ID of the Managed Identity with which you are using Workload Identity.
export AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-00000000000" # The Azure Subscription ID the identity is in.
export AZURE_TENANT_ID="00000000-0000-0000-0000-00000000000"       # The Azure AAD Tenant the identity/subscription is associated with.
export SERVICE_ACCOUNT_ISSUER="https://oidc.prod-aks.azure.com/00000000-0000-0000-0000-00000000000/" # The OIDC endpoint for your cluster in this example AKS
```

----------------------------------------

TITLE: Define Volume for Azure Identity Token (YAML)
DESCRIPTION: Defines the Kubernetes volume configuration using a projected service account token, necessary for Azure Workload Identity to authenticate within a pod.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/frequently-asked-questions.md#_snippet_6

LANGUAGE: YAML
CODE:
```
volumes:
- name: azure-identity-token
  projected:
    defaultMode: 420
    sources:
      - serviceAccountToken:
          audience: api://AzureADTokenExchange
          expirationSeconds: 3600
          path: azure-identity
```

----------------------------------------

TITLE: Creating ASO RoleAssignment Referencing ConfigMap (YAML)
DESCRIPTION: Demonstrates configuring an Azure Service Operator `RoleAssignment` resource to obtain the `principalId` from a Kubernetes `ConfigMap` named `identity-settings` using the `spec.principalIdFromConfig` field. This allows dynamic assignment based on values managed externally.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/configmaps.md#_snippet_0

LANGUAGE: YAML
CODE:
```
apiVersion: authorization.azure.com/v1api20200801preview
kind: RoleAssignment
metadata:
  name: fee8b6b1-fe6e-481d-8330-0e950e4e6b86 # Should be UUID
  namespace: default
spec:
  location: westcentralus
  # This resource can be owner by any resource. In this example we've chosen a resource group for simplicity
  owner:
    name: aso-sample-rg
    group: resources.azure.com
    kind: ResourceGroup
  # This is the Principal ID of the AAD identity to which the role will be assigned
  principalIdFromConfig:
    name: identity-settings
    key: principalId
  roleDefinitionReference:
    # This ARM ID represents "Contributor" - you can read about other built in roles here: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
    armId: /subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c
```

----------------------------------------

TITLE: Defining Dynamic Secrets in Azure Service Operator operatorSpec (Option 2)
DESCRIPTION: This YAML snippet shows how to define dynamic secrets within the `operatorSpec.dynamicSecrets` field. It specifies the destination secret name, the key within the secret, and a value derived from other secret fields using a format string.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/ADR-2024-07-Dynamic-Export-To-Secret-Or-ConfigMap.md#_snippet_4

LANGUAGE: YAML
CODE:
```
  operatorSpec:
    secrets:
      hostName:
        name: redis-secret
        key: hostName
      sslPort:
        name: redis-secret
        key: port
    dynamicSecrets:
      - name: redis-secret # Name of the destination secret
        key: hostPort # Name of the key in the secret
        value: "'%s:%s'.format([secret.hostName, secret.sslPort])" # Value (format) of the secret
```

----------------------------------------

TITLE: Importing Azure PostgreSQL Flexible Server using asoctl
DESCRIPTION: Demonstrates the `asoctl import azure-resource` command used to import an existing Azure PostgreSQL Flexible Server configuration. Requires the full ARM ID of the server and specifies an output file for the generated ASO YAML.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/tools/asoctl.md#_snippet_22

LANGUAGE: bash
CODE:
```
$ asoctl import azure-resource /subscriptions/[redacted]/resourceGroups/aso-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/aso-pg --output aso.yaml
```

----------------------------------------

TITLE: YAML Azure Generated Secret Destination Example
DESCRIPTION: Example YAML configuration showing how to use `operatorSpec.secrets` to specify where Azure-generated secrets (like storage account keys and endpoint) should be downloaded into a Kubernetes Secret named `my-secret`.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/secrets.md#_snippet_3

LANGUAGE: yaml
CODE:
```
spec:
  # Other spec fields elided...
  operatorSpec:
    secrets:
      primaryKey:
        name: my-secret
        key: PRIMARY_KEY
      secondaryKey:
        name: my-secret
        key: SECONDARY_KEY
      endpoint:
        name: my-secret
        key: ENDPOINT
```

----------------------------------------

TITLE: Create ASO Resource Referencing Secret (kubectl)
DESCRIPTION: Creates an Azure Resource Group using ASO, demonstrating how to reference a specific Kubernetes secret (`my-resource-secret`) for authentication instead of using global or namespace credentials. The `serviceoperator.azure.com/credential-from` annotation specifies the secret name. Requires kubectl access and ASO installed.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_7

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: aso-sample-rg
  namespace: default
  annotations:
    serviceoperator.azure.com/credential-from: my-resource-secret
spec:
  location: westcentralus
EOF
```

----------------------------------------

TITLE: Exporting a Specific Azure Resource with asoctl (Bash)
DESCRIPTION: This command demonstrates how to use `asoctl export resource` to export a single Azure resource, identified by its fully qualified ARM ID URL, into YAML format. The output is typically redirected to a file.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/design/ADR-2022-11-Resource-Import.md#_snippet_0

LANGUAGE: bash
CODE:
```
asoctl export resource http://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/vnet1
```

----------------------------------------

TITLE: Configure ASO Global Settings Secret (kubectl)
DESCRIPTION: Creates or updates the `aso-controller-settings` Kubernetes secret in the `azureserviceoperator-system` namespace. This secret stores global configuration, including Azure credentials (subscription, tenant, client IDs) and enables workload identity authentication for ASO. Requires kubectl access to the cluster.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/authentication/credential-format.md#_snippet_4

LANGUAGE: bash
CODE:
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
 name: aso-controller-settings
 namespace: azureserviceoperator-system
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
 USE_WORKLOAD_IDENTITY_AUTH: "true"
EOF
```

----------------------------------------

TITLE: Programmatically Create ASO ResourceGroup using Go Client
DESCRIPTION: Demonstrates how to use the `sigs.k8s.io/controller-runtime/pkg/client` and ASO's generated Go API types to programmatically create an Azure Resource Group Kubernetes resource. It shows importing necessary packages, setting up the scheme, creating a Kubernetes client, defining the resource object, and using the client to create it.
SOURCE: https://github.com/azure/azure-service-operator/blob/main/docs/hugo/content/guide/frequently-asked-questions.md#_snippet_2

LANGUAGE: Go
CODE:
```
package main

import (
 "sigs.k8s.io/controller-runtime/pkg/client"
 resources "github.com/Azure/azure-service-operator/v2/api/resources/v1api20200601"
 asoapi "github.com/Azure/azure-service-operator/v2/api"
 ctrl "sigs.k8s.io/controller-runtime"
)

func main() {
 scheme := asoapi.CreateScheme(scheme)
 kubeClient, err := client.New(config.GetConfigOrDie(), client.Options{Scheme: scheme})
 if err != nil {
  panic(err)
 }
 obj := &resources.ResourceGroup{
  ObjectMeta: ctrl.ObjectMeta{
   Name: "my-rg",
   Namespace: "my-namespace",
        },
  Spec: resources.ResourceGroup_Spec{
   Location: location,
  },
 }
 kubeClient.Create(ctx, obj)
}
```