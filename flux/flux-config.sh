#!/bin/bash
set -euo pipefail

# Environment variables
CLUSTER_NAME="aks-secure"
RESOURCE_GROUP="aks-secure-rg"
GITHUB_REPO="https://github.com/davidmarkgardiner/aso-flux.git"
GITHUB_BRANCH="main"
FLUX_NAMESPACE="flux-system"

# Create extension configuration
cat > extension.yaml << EOF
apiVersion: kubernetesconfiguration.azure.com/v1api20230501
kind: Extension
metadata:
  name: aso-flux-extension
  namespace: default
spec:
  autoUpgradeMinorVersion: true
  extensionType: microsoft.flux
  identity:
    type: SystemAssigned
  owner:
    group: containerservice.azure.com
    kind: ManagedCluster
    name: ${CLUSTER_NAME}
  scope:
    cluster:
      releaseNamespace: ${FLUX_NAMESPACE}
  configurationSettings:
    multiTenancy.enforce: "false"
    image-automation-controller.enabled: "true"
    image-reflector-controller.enabled: "true"
EOF

# Create Flux configuration
cat > fluxconfig.yaml << EOF
apiVersion: kubernetesconfiguration.azure.com/v1api20230501
kind: FluxConfiguration
metadata:
  name: aso-flux-config
  namespace: default
spec:
  gitRepository:
    repositoryRef:
      branch: ${GITHUB_BRANCH}
    url: ${GITHUB_REPO}
    timeoutInSeconds: 60
    syncIntervalInSeconds: 120
  kustomizations:
    apps:
      path: ./clusters/${CLUSTER_NAME}
      dependsOn: ["base"]
      timeoutInSeconds: 600
      syncIntervalInSeconds: 120
      prune: true
      force: true
    base:
      path: ./base
      dependsOn: []
      timeoutInSeconds: 300
      syncIntervalInSeconds: 60
      prune: true
      force: true
  namespace: ${FLUX_NAMESPACE}
  owner:
    group: containerservice.azure.com
    kind: ManagedCluster
    name: ${CLUSTER_NAME}
  sourceKind: GitRepository
  scope: cluster
EOF

echo "Applying Flux extension..."
kubectl apply -f extension.yaml

echo "Waiting for Flux extension to be installed..."
sleep 30

echo "Applying Flux configuration..."
kubectl apply -f fluxconfig.yaml

echo "Flux setup complete."
echo "To push configurations to the GitHub repository, use:"
echo "git clone ${GITHUB_REPO}"
echo "cd aso-flux"
echo "mkdir -p base clusters/${CLUSTER_NAME}"
echo "# Add configuration files"
echo "git add ."
echo "git commit -m 'Add Flux configuration'"
echo "git push origin ${GITHUB_BRANCH}"