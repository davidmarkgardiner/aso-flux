#!/bin/bash
set -euo pipefail

# Configure environment for deployment
SUBSCRIPTION_ID=""
LOCATION="uksouth"
RESOURCE_GROUP="aks-secure-rg"
CLUSTER_NAME="aks-secure"

# Set working directory to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up AKS Secure Cluster with Node Auto-Provisioning ==="
echo "Working directory: $(pwd)"

# Step 1: Create resource group
echo "Creating resource group..."
kubectl apply -f "$SCRIPT_DIR/improved-rg.yaml"
echo "Waiting for resource group creation..."
sleep 10

# Step 2: Create networking resources
echo "Creating network resources..."
kubectl apply -f "$SCRIPT_DIR/improved-vnet.yaml"
echo "Waiting for network resources creation..."
sleep 20

# Step 3: Create identity resources
echo "Creating identity resources..."
kubectl apply -f "$SCRIPT_DIR/improved-identity.yaml"
echo "Waiting for identity creation..."

# Step 4: Get identity details from the UserAssignedIdentity resources directly
echo "Retrieving identity details directly from UserAssignedIdentity resources..."

# Check if identities exist
if kubectl get userassignedidentity.managedidentity.azure.com aks-secure-identity -n default &>/dev/null; then
  echo "Identity aks-secure-identity exists, getting details..."
  IDENTITY_CLIENT_ID=$(kubectl get userassignedidentity.managedidentity.azure.com aks-secure-identity -n default -o jsonpath='{.status.clientId}' 2>/dev/null)
  IDENTITY_OBJECT_ID=$(kubectl get userassignedidentity.managedidentity.azure.com aks-secure-identity -n default -o jsonpath='{.status.principalId}' 2>/dev/null)
  
  if [ -z "$IDENTITY_CLIENT_ID" ] || [ -z "$IDENTITY_OBJECT_ID" ]; then
    echo "Could not retrieve identity details from the resource, trying ConfigMap..."
    IDENTITY_CLIENT_ID=$(kubectl get configmap aks-secure-identity-cm -n default -o jsonpath='{.data.clientId}' 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
    IDENTITY_OBJECT_ID=$(kubectl get configmap aks-secure-identity-cm -n default -o jsonpath='{.data.principalId}' 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
  fi
else
  echo "Identity aks-secure-identity not found, using placeholder"
  IDENTITY_CLIENT_ID="00000000-0000-0000-0000-000000000000"
  IDENTITY_OBJECT_ID="00000000-0000-0000-0000-000000000000"
fi

if kubectl get userassignedidentity.managedidentity.azure.com aks-secure-kubelet-identity -n default &>/dev/null; then
  echo "Identity aks-secure-kubelet-identity exists, getting details..."
  KUBELET_CLIENT_ID=$(kubectl get userassignedidentity.managedidentity.azure.com aks-secure-kubelet-identity -n default -o jsonpath='{.status.clientId}' 2>/dev/null)
  KUBELET_OBJECT_ID=$(kubectl get userassignedidentity.managedidentity.azure.com aks-secure-kubelet-identity -n default -o jsonpath='{.status.principalId}' 2>/dev/null)
  
  if [ -z "$KUBELET_CLIENT_ID" ] || [ -z "$KUBELET_OBJECT_ID" ]; then
    echo "Could not retrieve kubelet identity details from the resource, trying ConfigMap..."
    KUBELET_CLIENT_ID=$(kubectl get configmap aks-secure-kubelet-cm -n default -o jsonpath='{.data.clientId}' 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
    KUBELET_OBJECT_ID=$(kubectl get configmap aks-secure-kubelet-cm -n default -o jsonpath='{.data.principalId}' 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
  fi
else
  echo "Identity aks-secure-kubelet-identity not found, using placeholder"
  KUBELET_CLIENT_ID="00000000-0000-0000-0000-000000000000"
  KUBELET_OBJECT_ID="00000000-0000-0000-0000-000000000000"
fi

echo "Using identity details:"
echo "Control Plane Identity Client ID: $IDENTITY_CLIENT_ID"
echo "Control Plane Identity Object ID: $IDENTITY_OBJECT_ID"
echo "Kubelet Identity Client ID: $KUBELET_CLIENT_ID"
echo "Kubelet Identity Object ID: $KUBELET_OBJECT_ID"

# Step 5: Check if we're using placeholder values
if [ "${IDENTITY_OBJECT_ID:-}" = "00000000-0000-0000-0000-000000000000" ]; then
  echo "WARNING: Using placeholder values for identities. Skipping role assignments."
  echo "You will need to manually assign roles once the identities are created."
  echo "Run the following commands later:"
  echo "  IDENTITY_OBJECT_ID=\$(kubectl get configmap aks-secure-identity-cm -o jsonpath='{.data.principalId}')"
  echo "  KUBELET_OBJECT_ID=\$(kubectl get configmap aks-secure-kubelet-cm -o jsonpath='{.data.principalId}')"
  echo "  az role assignment create --assignee-object-id \$IDENTITY_OBJECT_ID --role \"Network Contributor\" --scope \"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP\""
  echo "  az role assignment create --assignee-object-id \$IDENTITY_OBJECT_ID --role \"Virtual Machine Contributor\" --scope \"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP\""
  echo "  az role assignment create --assignee-object-id \$KUBELET_OBJECT_ID --role \"Managed Identity Operator\" --scope \"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP\""
else
  # Grant necessary permissions to the identities
  echo "Granting required permissions to identities..."
  az role assignment create --assignee-object-id $IDENTITY_OBJECT_ID --role "Network Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
  az role assignment create --assignee-object-id $IDENTITY_OBJECT_ID --role "Virtual Machine Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
  az role assignment create --assignee-object-id $KUBELET_OBJECT_ID --role "Managed Identity Operator" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
fi

# Step 6: Update the cluster configuration with retrieved identity IDs
echo "Updating cluster configuration with identity IDs..."
cat "$SCRIPT_DIR/improved-cluster-working.yaml" | sed "s/\${KUBELET_CLIENT_ID}/$KUBELET_CLIENT_ID/g" | sed "s/\${KUBELET_OBJECT_ID}/$KUBELET_OBJECT_ID/g" > "$SCRIPT_DIR/improved-cluster-updated.yaml"

# Step 7: Create the AKS cluster with node auto-provisioning
echo "Creating AKS cluster with node auto-provisioning..."
kubectl apply -f "$SCRIPT_DIR/improved-cluster-updated.yaml"
echo "Waiting for cluster creation (this may take 10+ minutes)..."
echo "Waiting for 30 seconds before proceeding..."
sleep 30

# Step 8: Check if the cluster was created successfully
echo "Checking if the cluster was created successfully..."
if ! kubectl get managedcluster $CLUSTER_NAME -n default &>/dev/null; then
  echo "WARNING: Cluster does not appear to be created yet. This is normal, as ASO will process it asynchronously."
  echo "You can check the status with: kubectl get managedcluster $CLUSTER_NAME -n default -o yaml"
fi

# Step 9: Set up additional node pools
echo "Setting up additional node pools..."
kubectl apply -f "$SCRIPT_DIR/node-classes.yaml"

# Step 10: Deploy NAP test resources for auto-provisioning testing
echo "Deploying NAP test resources..."
kubectl apply -f "$SCRIPT_DIR/nap-test.yaml"

# Step 11: Deploy test workloads
echo "Deploying test applications..."
kubectl apply -f "$SCRIPT_DIR/test-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/batch-workload.yaml"

# Step 12: Verify deployment
echo "Verifying deployment..."
kubectl get managedcluster -n default
kubectl get userassignedidentity -n default

# Show kubectl commands to check progress
echo -e "\n=== Deployment In Progress ==="
echo "The Azure resources are being provisioned asynchronously."
echo "You can check the status with the following commands:"
echo "  kubectl get managedcluster $CLUSTER_NAME -n default -o yaml"
echo "  kubectl get userassignedidentity -n default"

echo -e "\nOnce the cluster is provisioned, check resources with:"
echo "  kubectl get nodeclaim -n default"
echo "  kubectl get nodeclass -n default"
echo "  kubectl get deployment -n default"
echo "  kubectl get pods -n default -o wide"

echo -e "\nAnd to check node auto-provisioning, monitor events with:"
echo "  kubectl get events -A --field-selector source=karpenter -w"