# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains configuration and documentation for deploying AKS (Azure Kubernetes Service) clusters using a multi-tiered management architecture with:
- Azure Service Operator (ASO) for infrastructure management
- Node Auto Provisioning (NAP) for dynamic node management  
- Kyverno for policy enforcement
- Flux v2 for GitOps with semantic versioning

## Architecture Overview

The deployment follows a hierarchical structure:
```
Master Management Cluster (ARM deployed)
├── Management Cluster - ENG (ASO deployed from master)
├── Management Cluster - DEV (ASO deployed from master)
├── Management Cluster - PREPROD (ASO deployed from master)
└── Management Cluster - PROD (ASO deployed from master)
    └── Each manages worker clusters and node pools
```

## Expected Repository Structure


```
environment/
├── eng/
│   ├── azureserviceoperator/
│   │   └── base/
│   │       ├── cluster/
│   │       │   ├── aks-cluster.yaml
│   │       │   └── kustomization.yaml
│   │       ├── configmap/
│   │       │   ├── cluster-config.yaml
│   │       │   └── kustomization.yaml
│   │       ├── flux/
│   │       │   ├── flux-config.yaml
│   │       │   ├── git-repository.yaml
│   │       │   └── kustomization.yaml
│   │       ├── resourcegroup/
│   │       │   ├── resource-group.yaml
│   │       │   └── kustomization.yaml
│   │       ├── identity/
│   │       │   ├── managed-identity.yaml
│   │       │   ├── role-assignment.yaml
│   │       │   └── kustomization.yaml
│   │       └── maintenanceconfiguration/
│   │           ├── maintenance-config.yaml
│   │           └── kustomization.yaml
│   ├── managementcluster/
│   │   └── [same structure as above]
│   └── napconfiguration/
│       └── base/
│           ├── kyvernopolicies/
│           │   ├── namespace-labeling-policies.yaml
│           │   └── kustomization.yaml
│           ├── nodepools/
│           │   ├── user-nodepool.yaml
│           │   ├── spot-nodepool.yaml
│           │   └── kustomization.yaml
│           └── nodeprovisioning/
│               ├── karpenter-nodeclass.yaml
│               ├── karpenter-nodepool.yaml
│               └── kustomization.yaml
├── dev/ [similar structure]
├── preprod/ [similar structure]
└── prod/ [similar structure]
```

## Key Validation Commands

### YAML Validation
```bash
# Validate YAML syntax
yamllint environment/ master-management/

# Validate Kubernetes resources
kubeval --strict environment/**/*.yaml master-management/**/*.yaml
```

### Kustomize Validation
```bash
# Validate all environment kustomizations
for env in eng dev preprod prod; do
  kustomize build environment/$env/azureserviceoperator/base/cluster --dry-run
  kustomize build environment/$env/napconfiguration/base --dry-run
done

# Validate master management kustomizations
kustomize build master-management/clusters --dry-run
```

### Policy and Security Validation
```bash
# Install and run conftest for policy validation
conftest verify --policy policies/ environment/ master-management/

# Install and run kube-score for security analysis
kube-score score environment/**/*.yaml master-management/**/*.yaml
```

## Critical Architectural Constraints

### NAP Configuration Separation
- Node pools MUST be in `napconfiguration/` folders, NOT in `azureserviceoperator/` folders
- Validation will fail if `ManagedClustersAgentPool` resources are found in ASO directories

### Azure RBAC Only
- No Kubernetes RBAC resources should be defined
- Use Azure RBAC for all access control
- Validation will fail if K8s Role/ClusterRole/RoleBinding/ClusterRoleBinding resources are found

### Semantic Versioning Strategy
- Development: `>=0.1.0 <1.0.0` (pre-release versions)
- Staging: `>=1.0.0-rc <1.0.0` (release candidates)  
- Production: `>=1.0.0 <2.0.0` (stable releases only)

## Flux substituteFrom Pattern

All configurations use Flux's `substituteFrom` feature for environment-specific values:
```yaml
substituteFrom:
- kind: ConfigMap
  name: ${ENVIRONMENT}-cluster-config
  optional: false
- kind: ConfigMap  
  name: ${ENVIRONMENT}-nap-config
  optional: false
```

## Azure DevOps Pipeline Configuration (Validation Only)

### Pipeline Structure (Triggered on File Changes)

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
    - develop
    - release/*
    - hotfix/*
  paths:
    include:
    - environment/*
    - master-management/*

pr:
  branches:
    include:
    - main
  paths:
    include:
    - environment/*
    - master-management/*

variables:
- group: aks-deployment-variables
- name: vmImageName
  value: 'ubuntu-latest'

stages:
- stage: Validate
  displayName: 'Validation Stage'
  jobs:
  - job: YAMLValidation
    displayName: 'YAML Validation and Linting'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: YamlLint@1
      displayName: 'YAML Lint Check'
      inputs:
        yamlPath: 'environment/ master-management/'
        configPath: '.yamllint.yml'
        
    - script: |
        # Install kubeval for Kubernetes YAML validation
        curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz
        sudo mv kubeval /usr/local/bin
        
        # Validate all Kubernetes YAML files
        find environment/ master-management/ -name "*.yaml" -type f | xargs kubeval --strict
      displayName: 'Kubernetes YAML Validation'
      
    - script: |
        # Install kustomize
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        
        # Build and validate kustomizations for all environments
        for env in eng dev preprod prod; do
          echo "Validating $env environment"
          
          # Validate ASO cluster configuration
          if [ -d "environment/$env/azureserviceoperator/base/cluster" ]; then
            kustomize build environment/$env/azureserviceoperator/base/cluster --dry-run
          fi
          
          # Validate NAP configuration  
          if [ -d "environment/$env/napconfiguration/base" ]; then
            kustomize build environment/$env/napconfiguration/base --dry-run
          fi
        done
        
        # Validate master management cluster configurations
        if [ -d "master-management/clusters" ]; then
          kustomize build master-management/clusters --dry-run
        fi
      displayName: 'Kustomize Build Validation'

- stage: SecurityScanning
  displayName: 'Security Scanning'
  dependsOn: Validate
  jobs:
  - job: PolicyValidation
    displayName: 'Policy and Security Validation'
    pool:
      vmImage: $(vmImageName)
    steps:
    - script: |
        # Install conftest for policy testing
        wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
        tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
        sudo mv conftest /usr/local/bin
        
        # Run policy tests against YAML files
        if [ -d "policies/" ]; then
          conftest verify --policy policies/ environment/ master-management/
        fi
      displayName: 'Policy Validation with Conftest'
      continueOnError: true
      
    - script: |
        # Install kube-score for security analysis
        wget https://github.com/zegl/kube-score/releases/download/v1.16.1/kube-score_1.16.1_linux_amd64.tar.gz
        tar xzf kube-score_1.16.1_linux_amd64.tar.gz
        sudo mv kube-score /usr/local/bin
        
        # Analyze configurations for security issues
        find environment/ master-management/ -name "*.yaml" -type f | xargs kube-score score
      displayName: 'Security Analysis with kube-score'
      continueOnError: true

- stage: DryRun
  displayName: 'Dry Run Deployment'
  dependsOn: SecurityScanning
  jobs:
  - job: DryRunDeployment
    displayName: 'Dry Run ASO and NAP Deployment'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: KubectlInstaller@0
      displayName: 'Install kubectl'
      
    - script: |
        # Test Flux substituteFrom functionality
        echo "Testing Flux substituteFrom configuration..."
        
        for env in eng dev preprod prod; do
          echo "Dry run for $env environment"
          
          # Create temporary directory for processed files
          mkdir -p /tmp/dry-run/$env
          
          # Test ConfigMap creation
          cat > /tmp/dry-run/$env/test-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-${env}-config
  namespace: aso-${env}
data:
  CLUSTER_NAME: "${env}-test-cluster"
  ENVIRONMENT: "$env"
  AZURE_REGION: "eastus"
EOF

          # Test Kustomization with substituteFrom
          cat > /tmp/dry-run/$env/test-kustomization.yaml << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: test-${env}
  namespace: flux-system
spec:
  interval: 5m
  path: "./environment/$env"
  sourceRef:
    kind: GitRepository
    name: aks-gitops
  substituteFrom:
  - kind: ConfigMap
    name: test-${env}-config
    optional: false
EOF
          
          # Validate processed YAML against Kubernetes API (dry-run)
          kubectl apply --dry-run=client -f /tmp/dry-run/$env/
        done
      displayName: 'Dry Run Validation with substituteFrom'

- stage: SemverValidation
  displayName: 'Semantic Versioning Validation'
  dependsOn: DryRun
  jobs:
  - job: SemverCheck
    displayName: 'Validate Semver Configuration'
    pool:
      vmImage: $(vmImageName)
    steps:
    - script: |
        # Validate semver ranges in GitRepository configurations
        echo "Validating semantic versioning configuration..."
        
        # Check for proper semver ranges
        find environment/ master-management/ -name "*.yaml" -type f -exec grep -l "semver:" {} \; | while read file; do
          echo "Checking semver configuration in: $file"
          
          # Extract semver ranges and validate format
          grep "semver:" "$file" | while read line; do
            semver_range=$(echo "$line" | sed 's/.*semver:[[:space:]]*["'\'']\(.*\)["'\'']/\1/')
            echo "Found semver range: $semver_range"
            
            # Basic validation of semver range format
            if [[ ! "$semver_range" =~ ^[>=<~\^0-9\.\-rc\.\*[:space:]]+$ ]]; then
              echo "ERROR: Invalid semver range format in $file: $semver_range"
              exit 1
            fi
          done
        done
        
        echo "Semver validation completed successfully"
      displayName: 'Validate Semver Ranges'

- stage: ComplianceCheck
  displayName: 'Compliance and Governance'
  dependsOn: SemverValidation
  jobs:
  - job: ComplianceValidation
    displayName: 'Validate Compliance Requirements'
    pool:
      vmImage: $(vmImageName)
    steps:
    - script: |
        # Check Azure RBAC configuration compliance
        echo "Validating Azure RBAC configurations..."
        
        # Ensure no Kubernetes RBAC is defined (Azure RBAC only)
        k8s_rbac_files=$(find environment/ master-management/ -name "*.yaml" -type f -exec grep -l "kind: \(Role\|ClusterRole\|RoleBinding\|ClusterRoleBinding\)" {} \;)
        
        if [ ! -z "$k8s_rbac_files" ]; then
          echo "ERROR: Kubernetes RBAC resources found. Use Azure RBAC only:"
          echo "$k8s_rbac_files"
          exit 1
        fi
        
        # Validate NAP configuration separation
        echo "Validating NAP configuration separation..."
        
        # Check that node pools are only in NAP folder, not in ASO folder
        aso_nodepool_files=$(find environment/*/azureserviceoperator/ -name "*.yaml" -type f -exec grep -l "kind: ManagedClustersAgentPool" {} \;)
        
        if [ ! -z "$aso_nodepool_files" ]; then
          echo "ERROR: Node pool configurations found in ASO folder. Move to NAP folder:"
          echo "$aso_nodepool_files"
          exit 1
        fi
        
        # Validate that node pools exist in NAP folders
        for env in eng dev preprod prod; do
          if [ ! -d "environment/$env/napconfiguration/base/nodepools" ]; then
            echo "WARNING: NAP nodepool configuration missing for $env environment"
          fi
        done
        
        echo "Compliance validation completed successfully"
      displayName: 'Azure RBAC and NAP Compliance Check'
```

### Security and Access Control (Azure RBAC Only)

Since Azure RBAC will handle cluster security instead of Kubernetes RBAC, the security model is simplified and leverages Azure's native identity and access management.

#### Azure RBAC Configuration
```yaml
# This configuration is handled outside of Kubernetes manifests
# Example Azure CLI commands for RBAC setup:

# Create custom role for AKS management
az role definition create --role-definition '{
  "Name": "AKS Platform Admin",
  "Description": "Full access to AKS platform resources",
  "Actions": [
    "Microsoft.ContainerService/*",
    "Microsoft.Resources/resourceGroups/*",
    "Microsoft.Network/*",
    "Microsoft.Compute/*"
  ],
  "NotActions": [],
  "AssignableScopes": ["/subscriptions/{subscription-id}"]
}'

# Assign role to management cluster identity
az role assignment create \
  --assignee {managed-identity-principal-id} \
  --role "AKS Platform Admin" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}
```

## Testing Strategy (File Change Triggered)

### 1. Unit Tests for YAML Validation

```bash
#!/bin/bash
# yaml-validation-tests.sh
# Triggered automatically when files change in the repository

echo "Running YAML validation tests..."

# Test 1: YAML syntax validation
echo "Test 1: YAML syntax validation"
changed_files=$(git diff --name-only HEAD~1 HEAD | grep -E '\.(yaml|yml)# AKS Deployment Plan with ASO, NAP, and Kyverno

## Overview
This deployment plan outlines the implementation of a multi-tiered AKS management architecture using Azure Service Operator (ASO), Node Auto Provisioning (NAP), and Kyverno for policy enforcement. The architecture features a master management cluster that manages environment-specific management clusters, which in turn manage worker clusters.
```
## Architecture Hierarchy

```
Master Management Cluster (ARM deployed)
├── Management Cluster - ENG (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
├── Management Cluster - DEV (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
├── Management Cluster - PREPROD (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
└── Management Cluster - PROD (ASO deployed from master)
    ├── Worker Clusters (ASO deployed)
    └── Node Pools (NAP configuration)
```

## Repository Structure

```
environment/
├── eng/
│   ├── azureserviceoperator/
│   │   └── base/
│   │       ├── cluster/
│   │       │   ├── aks-cluster.yaml
│   │       │   └── kustomization.yaml
│   │       ├── configmap/
│   │       │   ├── cluster-config.yaml
│   │       │   └── kustomization.yaml
│   │       ├── flux/
│   │       │   ├── flux-config.yaml
│   │       │   ├── git-repository.yaml
│   │       │   └── kustomization.yaml
│   │       ├── resourcegroup/
│   │       │   ├── resource-group.yaml
│   │       │   └── kustomization.yaml
│   │       ├── identity/
│   │       │   ├── managed-identity.yaml
│   │       │   ├── role-assignment.yaml
│   │       │   └── kustomization.yaml
│   │       └── maintenanceconfiguration/
│   │           ├── maintenance-config.yaml
│   │           └── kustomization.yaml
│   ├── managementcluster/
│   │   └── [same structure as above]
│   └── napconfiguration/
│       └── base/
│           ├── kyvernopolicies/
│           │   ├── namespace-labeling-policies.yaml
│           │   └── kustomization.yaml
│           ├── nodepools/
│           │   ├── user-nodepool.yaml
│           │   ├── spot-nodepool.yaml
│           │   └── kustomization.yaml
│           └── nodeprovisioning/
│               ├── karpenter-nodeclass.yaml
│               ├── karpenter-nodepool.yaml
│               └── kustomization.yaml
├── dev/ [similar structure]
├── preprod/ [similar structure]
└── prod/ [similar structure]
```

## Core YAML Configurations

### 1. ASO Cluster Configuration

#### aks-cluster.yaml
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  location: ${AZURE_REGION}
  resourceGroupRef:
    name: ${RESOURCE_GROUP_NAME}
  dnsPrefix: ${DNS_PREFIX}
  kubernetesVersion: ${K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: ${SERVICE_CIDR}
    dnsServiceIP: ${DNS_SERVICE_IP}
    dockerBridgeCidr: ${DOCKER_BRIDGE_CIDR}
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: ${MANAGED_IDENTITY_NAME}
  agentPoolProfiles:
  - name: systempool
    count: ${SYSTEM_NODE_COUNT}
    vmSize: ${SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: ${SYSTEM_MIN_NODES}
    maxCount: ${SYSTEM_MAX_NODES}
    enableNodePublicIP: false
    enableEncryptionAtHost: true
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: ${LOG_ANALYTICS_WORKSPACE_ID}
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true
```

#### management-cluster.yaml (deployed from master management cluster)
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${ENVIRONMENT}-management-cluster
  namespace: aso-master
spec:
  location: ${AZURE_REGION}
  resourceGroupRef:
    name: ${RESOURCE_GROUP_NAME}
  dnsPrefix: ${ENVIRONMENT}-mgmt
  kubernetesVersion: ${K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: 10.1.0.0/16
    dnsServiceIP: 10.1.0.10
    dockerBridgeCidr: 172.18.0.1/16
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: ${MANAGED_IDENTITY_NAME}
  agentPoolProfiles:
  - name: systempool
    count: ${SYSTEM_NODE_COUNT}
    vmSize: ${SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: ${SYSTEM_MIN_NODES}
    maxCount: ${SYSTEM_MAX_NODES}
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    nodeLabels:
      cluster-type: management
      environment: ${ENVIRONMENT}
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: ${LOG_ANALYTICS_WORKSPACE_ID}
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true

## Master Management Cluster Flux Configuration

### Master Cluster Kustomizations

#### master-flux-config.yaml
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: aks-gitops
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    branch: main
  secretRef:
    name: flux-git-auth
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: management-clusters
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: aks-gitops
  path: "./master-management/clusters"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: management-clusters-config
    optional: false
  - kind: Secret
    name: azure-credentials
    optional: false
  healthChecks:
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: eng-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: dev-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: preprod-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: prod-management-cluster
    namespace: aso-master
  timeout: 30m
```

### Environment-Specific Management Cluster Configurations

#### master-management/clusters/eng-management-cluster.yaml
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${ENG_CLUSTER_NAME}
  namespace: aso-master
spec:
  location: ${ENG_AZURE_REGION}
  resourceGroupRef:
    name: ${ENG_RESOURCE_GROUP_NAME}
  dnsPrefix: eng-mgmt
  kubernetesVersion: ${ENG_K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: 10.1.0.0/16
    dnsServiceIP: 10.1.0.10
    dockerBridgeCidr: 172.18.0.1/16
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: id-eng-management
  agentPoolProfiles:
  - name: systempool
    count: ${ENG_SYSTEM_NODE_COUNT}
    vmSize: ${ENG_SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: 3
    maxCount: 10
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    nodeLabels:
      cluster-type: management
      environment: eng
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-eng-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-eng
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true
```

### 2. Management Cluster Flux Configuration (deployed on each management cluster)

#### flux-config.yaml
```yaml
apiVersion: fluxcd.controlplane.azure.com/v1beta1
kind: FluxConfiguration
metadata:
  name: ${FLUX_CONFIG_NAME}
  namespace: ${NAMESPACE}
spec:
  clusterRef:
    name: ${CLUSTER_NAME}
  namespace: flux-system
  scope: cluster
  sourceKind: GitRepository
  gitRepository:
    url: ${GIT_REPOSITORY_URL}
    branch: ${GIT_BRANCH}
    repositoryRef:
      name: ${GIT_REPO_NAME}
  kustomizations:
  - name: cluster-config
    path: ${KUSTOMIZATION_PATH}
    prune: true
    dependsOn: []
    timeoutInSeconds: 600
    syncIntervalInSeconds: 300
    retryIntervalInSeconds: 120
    substituteFrom:
    - kind: ConfigMap
      name: ${ENVIRONMENT}-cluster-config
      optional: false
    - kind: Secret
      name: ${ENVIRONMENT}-cluster-secrets
      optional: true
  - name: nap-config
    path: ./environment/${ENVIRONMENT}/napconfiguration/base
    prune: true
    dependsOn:
    - cluster-config
    timeoutInSeconds: 600
    syncIntervalInSeconds: 300
    retryIntervalInSeconds: 120
    substituteFrom:
    - kind: ConfigMap
      name: ${ENVIRONMENT}-nap-config
      optional: false
  suspend: false
```

### 3. ConfigMaps for Environment Variables

#### cluster-config.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT}-cluster-config
  namespace: ${NAMESPACE}
data:
  CLUSTER_NAME: "${ENVIRONMENT}-aks-cluster"
  ENVIRONMENT: "${ENVIRONMENT}"
  AZURE_REGION: "${AZURE_REGION}"
  RESOURCE_GROUP_NAME: "rg-${ENVIRONMENT}-aks"
  NAMESPACE: "aso-${ENVIRONMENT}"
  K8S_VERSION: "1.28.5"
  DNS_PREFIX: "${ENVIRONMENT}-aks"
  SERVICE_CIDR: "10.0.0.0/16"
  DNS_SERVICE_IP: "10.0.0.10"
  DOCKER_BRIDGE_CIDR: "172.17.0.1/16"
  MANAGED_IDENTITY_NAME: "id-${ENVIRONMENT}-aks"
  SYSTEM_NODE_COUNT: "3"
  SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  SYSTEM_MIN_NODES: "3"
  SYSTEM_MAX_NODES: "10"
  LOG_ANALYTICS_WORKSPACE_ID: "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-${ENVIRONMENT}-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-${ENVIRONMENT}"
  GIT_REPOSITORY_URL: "https://github.com/your-org/aks-gitops"
  GIT_BRANCH: "main"
  KUSTOMIZATION_PATH: "./environment/${ENVIRONMENT}/azureserviceoperator/base"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT}-nap-config
  namespace: ${NAMESPACE}
data:
  NODEPOOL_NAME: "${ENVIRONMENT}-user-pool"
  NODEPOOL_COUNT: "2"
  NODEPOOL_VM_SIZE: "Standard_D4s_v3"
  NODEPOOL_MIN_COUNT: "1"
  NODEPOOL_MAX_COUNT: "20"
  WORKLOAD_TYPE: "general"
  NODE_TAINTS: "workload-type=${WORKLOAD_TYPE}:NoSchedule"
  CPU_REQUESTS_LIMIT: "100"
  MEMORY_REQUESTS_LIMIT: "200Gi"
  CPU_LIMITS_LIMIT: "200"
  MEMORY_LIMITS_LIMIT: "400Gi"
  PVC_LIMIT: "50"
  LB_LIMIT: "5"
  KARPENTER_NAMESPACE: "karpenter"
  KARPENTER_VERSION: "v0.32.0"
---
apiVersion: v1
kind: Secret
metadata:
  name: ${ENVIRONMENT}-cluster-secrets
  namespace: ${NAMESPACE}
type: Opaque
data:
  SUBSCRIPTION_ID: ${BASE64_SUBSCRIPTION_ID}
  TENANT_ID: ${BASE64_TENANT_ID}
  CLIENT_ID: ${BASE64_CLIENT_ID}
  CLIENT_SECRET: ${BASE64_CLIENT_SECRET}
```

#### management-cluster-config.yaml (for master management cluster)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: management-clusters-config
  namespace: aso-master
data:
  # ENG Management Cluster
  ENG_CLUSTER_NAME: "eng-management-cluster"
  ENG_AZURE_REGION: "eastus"
  ENG_RESOURCE_GROUP_NAME: "rg-eng-management"
  ENG_K8S_VERSION: "1.28.5"
  ENG_SYSTEM_NODE_COUNT: "3"
  ENG_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # DEV Management Cluster
  DEV_CLUSTER_NAME: "dev-management-cluster"
  DEV_AZURE_REGION: "eastus"
  DEV_RESOURCE_GROUP_NAME: "rg-dev-management"
  DEV_K8S_VERSION: "1.28.5"
  DEV_SYSTEM_NODE_COUNT: "3"
  DEV_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # PREPROD Management Cluster
  PREPROD_CLUSTER_NAME: "preprod-management-cluster"
  PREPROD_AZURE_REGION: "eastus"
  PREPROD_RESOURCE_GROUP_NAME: "rg-preprod-management"
  PREPROD_K8S_VERSION: "1.28.5"
  PREPROD_SYSTEM_NODE_COUNT: "3"
  PREPROD_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # PROD Management Cluster
  PROD_CLUSTER_NAME: "prod-management-cluster"
  PROD_AZURE_REGION: "eastus"
  PROD_RESOURCE_GROUP_NAME: "rg-prod-management"
  PROD_K8S_VERSION: "1.28.5"
  PROD_SYSTEM_NODE_COUNT: "5"
  PROD_SYSTEM_NODE_SIZE: "Standard_D8s_v3"
```

### 4. NAP Configuration (Node Pools deployed from NAP configuration folder)

#### Node Pools (deployed separately from NAP configuration)
```yaml
# napconfiguration/base/nodepools/user-nodepool.yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedClustersAgentPool
metadata:
  name: ${NODEPOOL_NAME}
  namespace: ${NAMESPACE}
spec:
  azureName: ${NODEPOOL_NAME}
  owner:
    name: ${CLUSTER_NAME}
  count: ${NODEPOOL_COUNT}
  vmSize: ${NODEPOOL_VM_SIZE}
  mode: User
  enableAutoScaling: true
  minCount: ${NODEPOOL_MIN_COUNT}
  maxCount: ${NODEPOOL_MAX_COUNT}
  enableNodePublicIP: false
  enableEncryptionAtHost: true
  nodeTaints:
  - ${NODE_TAINTS}
  nodeLabels:
    workload-type: ${WORKLOAD_TYPE}
    environment: ${ENVIRONMENT}
    managed-by: nap
    nodepool-type: user
---
# napconfiguration/base/nodepools/spot-nodepool.yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedClustersAgentPool
metadata:
  name: ${SPOT_NODEPOOL_NAME}
  namespace: ${NAMESPACE}
spec:
  azureName: ${SPOT_NODEPOOL_NAME}
  owner:
    name: ${CLUSTER_NAME}
  count: ${SPOT_NODEPOOL_COUNT}
  vmSize: ${SPOT_NODEPOOL_VM_SIZE}
  mode: User
  enableAutoScaling: true
  minCount: ${SPOT_NODEPOOL_MIN_COUNT}
  maxCount: ${SPOT_NODEPOOL_MAX_COUNT}
  enableNodePublicIP: false
  enableEncryptionAtHost: true
  scaleSetPriority: Spot
  scaleSetEvictionPolicy: Delete
  spotMaxPrice: ${SPOT_MAX_PRICE}
  nodeTaints:
  - spot=true:NoSchedule
  nodeLabels:
    workload-type: spot
    environment: ${ENVIRONMENT}
    managed-by: nap
    nodepool-type: spot
    kubernetes.azure.com/scalesetpriority: spot
---

#### Karpenter Node Provisioning
```yaml
# napconfiguration/base/nodeprovisioning/karpenter-nodeclass.yaml
apiVersion: karpenter.sh/v1beta1
kind: AKSNodeClass
metadata:
  name: ${ENVIRONMENT}-nodeclass
spec:
  imageFamily: AzureLinux
  subnetSelectorTerms:
  - tags:
      environment: ${ENVIRONMENT}
      karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelectorTerms:
  - tags:
      environment: ${ENVIRONMENT}
      karpenter.sh/discovery: ${CLUSTER_NAME}
  userData: |
    #!/bin/bash
    echo "Environment: ${ENVIRONMENT}" >> /etc/kubernetes/kubelet/kubelet-config.json
    echo "NodeClass: ${ENVIRONMENT}-nodeclass" >> /etc/kubernetes/kubelet/kubelet-config.json
---
# napconfiguration/base/nodeprovisioning/karpenter-nodepool.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: ${ENVIRONMENT}-nodepool
spec:
  template:
    metadata:
      labels:
        environment: ${ENVIRONMENT}
        managed-by: karpenter
        cluster-name: ${CLUSTER_NAME}
    spec:
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3"]
      nodeClassRef:
        apiVersion: karpenter.sh/v1beta1
        kind: AKSNodeClass
        name: ${ENVIRONMENT}-nodeclass
      taints:
      - key: workload-type
        value: ${WORKLOAD_TYPE}
        effect: NoSchedule
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
```

### 5. Kyverno Policies (Simplified - Focus on Namespace Labeling)

#### namespace-labeling-policies.yaml
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-namespace-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-environment-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
    validate:
      message: "Namespace must have environment label"
      pattern:
        metadata:
          labels:
            environment: "?*"
  - name: require-workload-type-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
    validate:
      message: "Namespace must have workload-type label"
      pattern:
        metadata:
          labels:
            workload-type: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-pod-tolerations
spec:
  background: true
  rules:
  - name: add-tolerations-based-on-namespace
    match:
      any:
      - resources:
          kinds:
          - Pod
    generate:
      apiVersion: v1
      kind: Pod
      synchronize: true
      data:
        spec:
          tolerations:
          - key: workload-type
            operator: Equal
            value: "{{request.namespace.metadata.labels.workload-type}}"
            effect: NoSchedule
```

## Semantic Versioning with Flux

### Overview
Flux v2 supports semantic versioning (semver) in GitRepository sources, allowing you to create platform releases and separate non-prod and prod clusters with better deployment control. This enables automatic synchronization based on semantic version ranges instead of static branches or tags.

### Environment-Specific Semver Strategy

#### Development/Engineering Environment
- **Semver Range**: `>=0.1.0 <1.0.0` (Pre-release versions)
- **Purpose**: Latest development builds and features
- **Auto-deployment**: Yes, for rapid iteration

#### Staging/Pre-production Environment  
- **Semver Range**: `>=1.0.0-rc <1.0.0` (Release candidates)
- **Purpose**: Release candidate testing
- **Auto-deployment**: Yes, for validation

#### Production Environment
- **Semver Range**: `>=1.0.0 <2.0.0` (Stable releases only)
- **Purpose**: Production-ready stable releases
- **Auto-deployment**: Controlled, with approval gates

### GitRepository Configuration with Semver

#### Development Environment Git Repository
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-dev
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=0.1.0 <1.0.0"
  secretRef:
    name: flux-git-auth
```

#### Staging Environment Git Repository  
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-staging
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=1.0.0-rc <1.0.0"
  secretRef:
    name: flux-git-auth
```

#### Production Environment Git Repository
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-prod
  namespace: flux-system
spec:
  interval: 30m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=1.0.0 <2.0.0"
  secretRef:
    name: flux-git-auth
```

### Kustomization with Environment-Specific Sources

#### Engineering Environment Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: eng-cluster-config
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-dev
  path: "./environment/eng"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: eng-cluster-config
    optional: false
  - kind: ConfigMap
    name: eng-nap-config
    optional: false
  timeout: 10m
```

#### Production Environment Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: prod-cluster-config
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-prod
  path: "./environment/prod"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: prod-cluster-config
    optional: false
  - kind: ConfigMap
    name: prod-nap-config
    optional: false
  timeout: 20m
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: azure-service-operator
    namespace: azureserviceoperator-system
```

### Release Workflow with Semver

#### Version Tagging Strategy
```bash
# Development releases (frequent)
git tag v0.1.0    # Initial development
git tag v0.1.1    # Development patches
git tag v0.2.0    # New development features

# Release candidates (staging)
git tag v1.0.0-rc.1    # First release candidate
git tag v1.0.0-rc.2    # Second release candidate

# Production releases (stable)
git tag v1.0.0    # Production release
git tag v1.0.1    # Production patch
git tag v1.1.0    # Production minor release
git tag v2.0.0    # Production major release
```

### Advanced Semver Configurations

#### Pre-release Pattern Matching
```yaml
# For alpha releases in development
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-alpha
  namespace: flux-system
spec:
  interval: 2m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=0.1.0-alpha <1.0.0"
```

#### Hotfix Releases for Production
```yaml
# For emergency hotfixes
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-hotfix
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: "~1.0.0"  # Only patch versions of 1.0.x
```

### Pipeline Structure

```yaml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    include:
    - environment/*

variables:
- group: aks-deployment-variables
- name: vmImageName
  value: 'ubuntu-latest'

stages:
- stage: Validate
  displayName: 'Validation Stage'
  jobs:
  - job: YAMLValidation
    displayName: 'YAML Validation and Linting'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: YamlLint@1
      displayName: 'YAML Lint Check'
      inputs:
        yamlPath: 'environment/'
        configPath: '.yamllint.yml'
        
    - script: |
        # Install kubeval for Kubernetes YAML validation
        curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz
        sudo mv kubeval /usr/local/bin
        
        # Validate all Kubernetes YAML files
        find environment/ -name "*.yaml" -type f | xargs kubeval --strict
      displayName: 'Kubernetes YAML Validation'
      
    - script: |
        # Install kustomize
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        
        # Build and validate kustomizations
        for env in eng dev preprod prod; do
          echo "Validating $env environment"
          kustomize build environment/$env/azureserviceoperator/base/cluster --dry-run
          kustomize build environment/$env/napconfiguration/base --dry-run
        done
      displayName: 'Kustomize Build Validation'

- stage: SecurityScanning
  displayName: 'Security Scanning'
  dependsOn: Validate
  jobs:
  - job: PolicyValidation
    displayName: 'Policy and Security Validation'
    pool:
      vmImage: $(vmImageName)
    steps:
    - script: |
        # Install conftest for policy testing
        wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
        tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
        sudo mv conftest /usr/local/bin
        
        # Run policy tests against YAML files
        conftest verify --policy policies/ environment/
      displayName: 'Policy Validation with Conftest'
      
    - script: |
        # Install kube-score for security analysis
        wget https://github.com/zegl/kube-score/releases/download/v1.16.1/kube-score_1.16.1_linux_amd64.tar.gz
        tar xzf kube-score_1.16.1_linux_amd64.tar.gz
        sudo mv kube-score /usr/local/bin
        
        # Analyze configurations for security issues
        find environment/ -name "*.yaml" -type f | xargs kube-score score
      displayName: 'Security Analysis with kube-score'

- stage: DryRun
  displayName: 'Dry Run Deployment'
  dependsOn: SecurityScanning
  jobs:
  - job: DryRunDeployment
    displayName: 'Dry Run ASO Deployment'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: KubectlInstaller@0
      displayName: 'Install kubectl'
      
    - script: |
        # Simulate Flux substitution for dry run
        for env in eng dev preprod prod; do
          echo "Dry run for $env environment"
          
          # Create temporary directory for processed files
          mkdir -p /tmp/dry-run/$env
          
          # Process templates with environment variables
          envsubst < environment/$env/azureserviceoperator/base/cluster/aks-cluster.yaml > /tmp/dry-run/$env/aks-cluster.yaml
          
          # Validate processed YAML against Kubernetes API (dry-run)
          kubectl apply --dry-run=client -f /tmp/dry-run/$env/aks-cluster.yaml
        done
      displayName: 'Dry Run Deployment Validation'
      env:
        CLUSTER_NAME: 'test-cluster'
        ENVIRONMENT: 'test'
        AZURE_REGION: 'eastus'
        RESOURCE_GROUP_NAME: 'rg-test'
        NAMESPACE: 'aso-test'

- stage: Deploy
  displayName: 'Deployment Stage'
  dependsOn: DryRun
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployToManagementCluster
    displayName: 'Deploy to Management Cluster'
    environment: 'aks-management-cluster'
    pool:
      vmImage: $(vmImageName)
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: 'Apply ASO Configurations'
            inputs:
              action: 'deploy'
              manifests: |
                environment/$(ENVIRONMENT)/azureserviceoperator/base/**/*.yaml
              namespace: 'aso-$(ENVIRONMENT)'
```

## Security and Access Control

### Master Management Cluster Security

#### RBAC Configuration
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: master-management-cluster-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: master-management-cluster-admin-binding
subjects:
- kind: Group
  name: aks-platform-admins
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: master-management-cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: management-cluster-operator
rules:
- apiGroups: ["containerservice.azure.com"]
  resources: ["managedclusters", "managedclustersagentpools"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["fluxcd.controlplane.azure.com"]
  resources: ["fluxconfigurations"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

#### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: aso-master
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-aso-operator
  namespace: aso-master
spec:
  podSelector:
    matchLabels:
      app: azure-service-operator
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: flux-system
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
```

### Monitoring and Alerting

#### Critical Alerts Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: master-cluster-alerts
  namespace: monitoring
data:
  alerts.yaml: |
    groups:
    - name: master-management-cluster
      rules:
      - alert: MasterClusterDown
        expr: up{job="kubernetes-nodes"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Master management cluster is down"
          description: "The master management cluster has been down for more than 1 minute"
          
      - alert: ASOOperatorDown
        expr: up{job="azure-service-operator"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "ASO Operator is down"
          description: "Azure Service Operator has been down for more than 2 minutes"
          
      - alert: FluxReconciliationFailed
        expr: gotk_reconcile_condition{type="Ready",status="False"} == 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Flux reconciliation failed"
          description: "Flux reconciliation has been failing for {{ $labels.name }}"
```

## Testing Strategy

### 1. Unit Tests for YAML Validation

```bash
#!/bin/bash
# yaml-validation-tests.sh

echo "Running YAML validation tests..."

# Test 1: YAML syntax validation
echo "Test 1: YAML syntax validation"
for file in $(find environment/ -name "*.yaml"); do
    if ! yamllint "$file"; then
        echo "FAIL: $file has syntax errors"
        exit 1
    fi
done
echo "PASS: All YAML files have valid syntax"

# Test 2: Kubernetes resource validation
echo "Test 2: Kubernetes resource validation"
for file in $(find environment/ -name "*.yaml"); do
    if ! kubeval "$file"; then
        echo "FAIL: $file has invalid Kubernetes resources"
        exit 1
    fi
done
echo "PASS: All Kubernetes resources are valid"

# Test 3: Kustomization build tests
echo "Test 3: Kustomization build tests"
for env in eng dev preprod prod; do
    if ! kustomize build "environment/$env/azureserviceoperator/base/cluster"; then
        echo "FAIL: Kustomization build failed for $env"
        exit 1
    fi
done
echo "PASS: All kustomizations build successfully"
```

### 2. Integration Tests

```bash
#!/bin/bash
# integration-tests.sh

echo "Running integration tests..."

# Test 1: Flux substitution test
echo "Test 1: Testing Flux variable substitution"
test_substitution() {
    local env=$1
    export CLUSTER_NAME="test-${env}-cluster"
    export ENVIRONMENT="$env"
    export AZURE_REGION="eastus"
    
    # Process template
    envsubst < "environment/$env/azureserviceoperator/base/cluster/aks-cluster.yaml" > "/tmp/test-$env.yaml"
    
    # Verify substitution worked
    if grep -q '${' "/tmp/test-$env.yaml"; then
        echo "FAIL: Variable substitution incomplete for $env"
        return 1
    fi
    
    # Validate processed YAML
    if ! kubeval "/tmp/test-$env.yaml"; then
        echo "FAIL: Processed YAML invalid for $env"
        return 1
    fi
    
    echo "PASS: Variable substitution successful for $env"
}

for env in eng dev preprod prod; do
    test_substitution "$env"
done

# Test 2: Policy validation
echo "Test 2: Testing Kyverno policies"
conftest verify --policy policies/ environment/

echo "All integration tests completed"
```

### 3. End-to-End Testing

```bash
#!/bin/bash
# e2e-tests.sh

echo "Running end-to-end tests..."

# Test 1: Deploy test cluster
echo "Test 1: Deploying test cluster"
kubectl apply -f test-manifests/test-cluster.yaml
kubectl wait --for=condition=Ready managedcluster/test-cluster --timeout=1200s

# Test 2: Verify NAP functionality
echo "Test 2: Testing Node Auto Provisioning"
kubectl apply -f test-manifests/test-workload.yaml
kubectl wait --for=condition=Ready pod/test-workload --timeout=600s

# Test 3: Verify Kyverno policies
echo "Test 3: Testing Kyverno policy enforcement"
if kubectl apply -f test-manifests/privileged-pod.yaml 2>&1 | grep -q "denied"; then
    echo "PASS: Kyverno policy correctly denied privileged pod"
else
    echo "FAIL: Kyverno policy did not deny privileged pod"
    exit 1
fi

# Cleanup
kubectl delete -f test-manifests/test-cluster.yaml
kubectl delete -f test-manifests/test-workload.yaml

echo "All end-to-end tests completed successfully"
```

## Deployment Workflow

### 1. Pre-deployment Checklist

- [ ] YAML syntax validation passed
- [ ] Kubernetes resource validation passed
- [ ] Kustomization builds successful
- [ ] Security policies validated
- [ ] Dry run deployment successful
- [ ] Environment-specific variables configured
- [ ] RBAC permissions verified
- [ ] Network policies applied
- [ ] Monitoring and alerting configured

### 2. Deployment Process

1. **Master Management Cluster Deployment**
   - Deploy via ARM template
   - Install ASO operator
   - Configure Flux for management cluster deployments
   - Create ConfigMaps with management cluster configurations
   - Apply security policies
   - Verify cluster health

2. **Environment Management Clusters (deployed via ASO from master)**
   - Master management cluster deploys management clusters using ASO
   - Management clusters automatically get ASO operator installed
   - Configure Flux with environment-specific ConfigMaps using `substituteFrom`
   - Apply NAP configuration from dedicated folder
   - Install Kyverno
   - Verify cluster health

3. **Worker Clusters (deployed via ASO from management clusters)**
   - Deploy via ASO from respective management clusters
   - Apply NAP node pools from NAP configuration folder
   - Configure Kyverno policies using `substituteFrom`
   - Verify application readiness

### 3. Rollback Strategy

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rollback-procedures
data:
  rollback.sh: |
    #!/bin/bash
    # Emergency rollback procedure
    
    echo "Initiating rollback procedure..."
    
    # Step 1: Suspend Flux reconciliation
    kubectl patch gitrepository aks-gitops -n flux-system --type='merge' -p='{"spec":{"suspend":true}}'
    
    # Step 2: Rollback to previous known good state
    kubectl apply -f backup-manifests/last-known-good/
    
    # Step 3: Verify cluster health
    kubectl get nodes
    kubectl get pods -A
    
    # Step 4: Re-enable Flux if rollback successful
    if [ $? -eq 0 ]; then
        kubectl patch gitrepository aks-gitops -n flux-system --type='merge' -p='{"spec":{"suspend":false}}'
        echo "Rollback completed successfully"
    else
        echo "Rollback failed - manual intervention required"
        exit 1
    fi
```

## Monitoring and Maintenance

### Health Checks

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: health-check-scripts
data:
  cluster-health.sh: |
    #!/bin/bash
    # Comprehensive cluster health check
    
    echo "=== Cluster Health Check ==="
    
    # Check node status
    echo "Node Status:"
    kubectl get nodes -o wide
    
    # Check system pods
    echo "System Pods Status:"
    kubectl get pods -n kube-system
    
    # Check ASO operator
    echo "ASO Operator Status:"
    kubectl get pods -n azureserviceoperator-system
    
    # Check Flux status
    echo "Flux Status:"
    kubectl get gitrepositories,kustomizations -n flux-system
    
    # Check Kyverno status
    echo "Kyverno Status:"
    kubectl get pods -n kyverno
    
    # Check cluster resources
    echo "Cluster Resource Usage:"
    kubectl top nodes
    kubectl top pods -A
    
    # Check for failed reconciliations
    echo "Failed Reconciliations:"
    kubectl get kustomizations -A -o json | jq '.items[] | select(.status.conditions[]?.status == "False") | .metadata.name'
```

This comprehensive deployment plan provides a robust foundation for managing AKS clusters using ASO, NAP, and Kyverno with proper security, testing, and operational procedures.)

if [ -z "$changed_files" ]; then
  echo "No YAML files changed, skipping validation"
  exit 0
fi

for file in $changed_files; do
    if [ -f "$file" ]; then
        if ! yamllint "$file"; then
            echo "FAIL: $file has syntax errors"
            exit 1
        fi
    fi
done
echo "PASS: All changed YAML files have valid syntax"

# Test 2: Kubernetes resource validation
echo "Test 2: Kubernetes resource validation"
for file in $changed_files; do
    if [ -f "$file" ]; then
        if ! kubeval "$file"; then
            echo "FAIL: $file has invalid Kubernetes resources"
            exit 1
        fi
    fi
done
echo "PASS: All changed Kubernetes resources are valid"

# Test 3: NAP configuration separation validation
echo "Test 3: NAP configuration separation validation"
aso_files_with_nodepools=$(echo "$changed_files" | grep "azureserviceoperator" | xargs grep -l "ManagedClustersAgentPool" 2>/dev/null || true)

if [ ! -z "$aso_files_with_nodepools" ]; then
    echo "FAIL: Node pool configurations found in ASO folder:"
    echo "$aso_files_with_nodepools"
    exit 1
fi
echo "PASS: NAP configuration properly separated"
```

### 2. Integration Tests

```bash
#!/bin/bash
# integration-tests.sh

echo "Running integration tests..."

# Test 1: Testing Flux substituteFrom functionality
echo "Test 1: Testing Flux substituteFrom variable substitution"
test_substitute_from() {
    local env=$1
    
    # Create test ConfigMap
    kubectl create configmap test-${env}-config \
        --from-literal=CLUSTER_NAME="test-${env}-cluster" \
        --from-literal=ENVIRONMENT="$env" \
        --from-literal=AZURE_REGION="eastus" \
        --dry-run=client -o yaml > "/tmp/test-${env}-configmap.yaml"
    
    # Create test Kustomization with substituteFrom
    cat > "/tmp/test-${env}-kustomization.yaml" << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: test-${env}
  namespace: flux-system
spec:
  interval: 5m
  path: "./test"
  sourceRef:
    kind: GitRepository
    name: test-repo
  substituteFrom:
  - kind: ConfigMap
    name: test-${env}-config
    optional: false
EOF
    
    # Validate YAML structure
    if ! kubeval "/tmp/test-${env}-kustomization.yaml"; then
        echo "FAIL: Kustomization with substituteFrom invalid for $env"
        return 1
    fi
    
    echo "PASS: substituteFrom configuration valid for $env"
}

for env in eng dev preprod prod; do
    test_substitute_from "$env"
done

# Test 2: Validate NAP configuration structure
echo "Test 2: Testing NAP configuration deployment"
for env in eng dev preprod prod; do
    echo "Validating NAP configuration for $env"
    
    # Validate NAP folder structure
    if [ ! -d "environment/$env/napconfiguration/base" ]; then
        echo "FAIL: NAP configuration folder missing for $env"
        exit 1
    fi
    
    # Validate NAP kustomization
    if ! kustomize build "environment/$env/napconfiguration/base"; then
        echo "FAIL: NAP kustomization build failed for $env"
        exit 1
    fi
done

# Test 3: Semver configuration validation
echo "Test 3: Testing semantic versioning configuration"
semver_test() {
    local range=$1
    local expected_behavior=$2
    
    # Test semver range validity
    cat > "/tmp/test-gitrepo-semver.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: test-semver
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/test/repo
  ref:
    semver: "$range"
EOF
    
    if ! kubeval "/tmp/test-gitrepo-semver.yaml"; then
        echo "FAIL: Invalid semver configuration: $range"
        return 1
    fi
    
    echo "PASS: Semver range '$range' is valid"
}

# Test various semver ranges
semver_test ">=0.1.0 <1.0.0" "development"
semver_test ">=1.0.0-rc <1.0.0" "staging"  
semver_test ">=1.0.0 <2.0.0" "production"
semver_test "~1.0.0" "hotfix"

echo "All integration tests completed"
```

### 3. End-to-End Testing (Automated on File Changes)

```bash
#!/bin/bash
# e2e-tests.sh

echo "Running end-to-end tests..."

# Test 1: Deploy test cluster configuration
echo "Test 1: Testing cluster configuration deployment"
kubectl apply --dry-run=server -f test-manifests/test-cluster.yaml

# Test 2: Verify NAP configuration processing
echo "Test 2: Testing NAP configuration processing"
kubectl apply --dry-run=server -f test-manifests/test-nap-config.yaml

# Test 3: Verify Kyverno policy enforcement
echo "Test 3: Testing Kyverno policy enforcement"

# Test namespace without required labels (should fail)
cat > "/tmp/test-namespace-invalid.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-invalid
EOF

if kubectl apply --dry-run=server -f "/tmp/test-namespace-invalid.yaml" 2>&1 | grep -q "denied"; then
    echo "PASS: Kyverno policy correctly denied namespace without labels"
else
    echo "FAIL: Kyverno policy did not deny invalid namespace"
    exit 1
fi

# Test namespace with required labels (should pass)
cat > "/tmp/test-namespace-valid.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-valid
  labels:
    environment: test
    workload-type: general
EOF

if kubectl apply --dry-run=server -f "/tmp/test-namespace-valid.yaml"; then
    echo "PASS: Kyverno policy correctly allowed valid namespace"
else
    echo "FAIL: Kyverno policy incorrectly denied valid namespace"
    exit 1
fi

echo "All end-to-end tests completed successfully"
```

## Deployment Workflow (Updated)

### 1. Pre-deployment Checklist

- [ ] YAML syntax validation passed
- [ ] Kubernetes resource validation passed
- [ ] Kustomization builds successful
- [ ] NAP configuration separated from ASO
- [ ] Semver ranges properly configured
- [ ] Dry run deployment successful
- [ ] Environment-specific variables configured via ConfigMaps
- [ ] Azure RBAC permissions verified
- [ ] Kyverno policies validated for namespace labeling
- [ ] Monitoring and alerting configured

### 2. Updated Deployment Process

1. **Master Management Cluster Deployment**
   - Deploy via ARM template
   - Install ASO operator
   - Configure Flux for management cluster deployments with appropriate semver ranges
   - Create ConfigMaps with management cluster configurations
   - Apply simplified security policies (Azure RBAC)
   - Verify cluster health

2. **Environment Management Clusters (deployed via ASO from master)**
   - Master management cluster deploys management clusters using ASO
   - Management clusters automatically get ASO operator installed
   - Configure Flux with environment-specific ConfigMaps using `substituteFrom`
   - Configure appropriate semver ranges per environment
   - Apply NAP configuration from dedicated folder structure
   - Install Kyverno for namespace labeling only
   - Verify cluster health

3. **Worker Clusters (deployed via ASO from management clusters)**
   - Deploy via ASO from respective management clusters
   - Apply NAP node pools from NAP configuration folder
   - Configure Kyverno policies for namespace-based taints/tolerations
   - Verify application readiness

### 3. Semver-Based Release Process

```bash
# Development workflow
git checkout develop
# Make changes to configurations
git commit -m "feat: add new node pool configuration"
git tag v0.2.0
git push origin develop --tags

# Release candidate workflow  
git checkout main
git merge develop
git tag v1.0.0-rc.1
git push origin main --tags

# Production release workflow
# After RC validation
git tag v1.0.0
git push origin main --tags
```

This updated deployment plan now properly separates node pools into the NAP configuration folder, removes unnecessary security policies and resource quotas (handled by Kyverno based on namespace labels), implements semantic versioning with Flux, and focuses the pipeline on validation triggered by file changes rather than deployment. The Azure RBAC approach simplifies security management by leveraging Azure's native identity and access management instead of complex Kubernetes RBAC configurations.# AKS Deployment Plan with ASO, NAP, and Kyverno

## Overview
This deployment plan outlines the implementation of a multi-tiered AKS management architecture using Azure Service Operator (ASO), Node Auto Provisioning (NAP), and Kyverno for policy enforcement. The architecture features a master management cluster that manages environment-specific management clusters, which in turn manage worker clusters.

## Architecture Hierarchy

```
Master Management Cluster (ARM deployed)
├── Management Cluster - ENG (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
├── Management Cluster - DEV (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
├── Management Cluster - PREPROD (ASO deployed from master)
│   ├── Worker Clusters (ASO deployed)
│   └── Node Pools (NAP configuration)
└── Management Cluster - PROD (ASO deployed from master)
    ├── Worker Clusters (ASO deployed)
    └── Node Pools (NAP configuration)
```

## Repository Structure

```
environment/
├── eng/
│   ├── azureserviceoperator/
│   │   └── base/
│   │       ├── cluster/
│   │       │   ├── aks-cluster.yaml
│   │       │   └── kustomization.yaml
│   │       ├── configmap/
│   │       │   ├── cluster-config.yaml
│   │       │   └── kustomization.yaml
│   │       ├── flux/
│   │       │   ├── flux-config.yaml
│   │       │   ├── git-repository.yaml
│   │       │   └── kustomization.yaml
│   │       ├── resourcegroup/
│   │       │   ├── resource-group.yaml
│   │       │   └── kustomization.yaml
│   │       ├── identity/
│   │       │   ├── managed-identity.yaml
│   │       │   ├── role-assignment.yaml
│   │       │   └── kustomization.yaml
│   │       └── maintenanceconfiguration/
│   │           ├── maintenance-config.yaml
│   │           └── kustomization.yaml
│   ├── managementcluster/
│   │   └── [same structure as above]
│   └── napconfiguration/
│       └── base/
│           ├── kyvernopolicies/
│           │   ├── namespace-labeling-policies.yaml
│           │   └── kustomization.yaml
│           ├── nodepools/
│           │   ├── user-nodepool.yaml
│           │   ├── spot-nodepool.yaml
│           │   └── kustomization.yaml
│           └── nodeprovisioning/
│               ├── karpenter-nodeclass.yaml
│               ├── karpenter-nodepool.yaml
│               └── kustomization.yaml
├── dev/ [similar structure]
├── preprod/ [similar structure]
└── prod/ [similar structure]
```

## Core YAML Configurations

### 1. ASO Cluster Configuration

#### aks-cluster.yaml
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  location: ${AZURE_REGION}
  resourceGroupRef:
    name: ${RESOURCE_GROUP_NAME}
  dnsPrefix: ${DNS_PREFIX}
  kubernetesVersion: ${K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: ${SERVICE_CIDR}
    dnsServiceIP: ${DNS_SERVICE_IP}
    dockerBridgeCidr: ${DOCKER_BRIDGE_CIDR}
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: ${MANAGED_IDENTITY_NAME}
  agentPoolProfiles:
  - name: systempool
    count: ${SYSTEM_NODE_COUNT}
    vmSize: ${SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: ${SYSTEM_MIN_NODES}
    maxCount: ${SYSTEM_MAX_NODES}
    enableNodePublicIP: false
    enableEncryptionAtHost: true
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: ${LOG_ANALYTICS_WORKSPACE_ID}
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true
```

#### management-cluster.yaml (deployed from master management cluster)
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${ENVIRONMENT}-management-cluster
  namespace: aso-master
spec:
  location: ${AZURE_REGION}
  resourceGroupRef:
    name: ${RESOURCE_GROUP_NAME}
  dnsPrefix: ${ENVIRONMENT}-mgmt
  kubernetesVersion: ${K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: 10.1.0.0/16
    dnsServiceIP: 10.1.0.10
    dockerBridgeCidr: 172.18.0.1/16
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: ${MANAGED_IDENTITY_NAME}
  agentPoolProfiles:
  - name: systempool
    count: ${SYSTEM_NODE_COUNT}
    vmSize: ${SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: ${SYSTEM_MIN_NODES}
    maxCount: ${SYSTEM_MAX_NODES}
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    nodeLabels:
      cluster-type: management
      environment: ${ENVIRONMENT}
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: ${LOG_ANALYTICS_WORKSPACE_ID}
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true

## Master Management Cluster Flux Configuration

### Master Cluster Kustomizations

#### master-flux-config.yaml
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: aks-gitops
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    branch: main
  secretRef:
    name: flux-git-auth
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: management-clusters
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: aks-gitops
  path: "./master-management/clusters"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: management-clusters-config
    optional: false
  - kind: Secret
    name: azure-credentials
    optional: false
  healthChecks:
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: eng-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: dev-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: preprod-management-cluster
    namespace: aso-master
  - apiVersion: containerservice.azure.com/v1api20231001
    kind: ManagedCluster
    name: prod-management-cluster
    namespace: aso-master
  timeout: 30m
```

### Environment-Specific Management Cluster Configurations

#### master-management/clusters/eng-management-cluster.yaml
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: ${ENG_CLUSTER_NAME}
  namespace: aso-master
spec:
  location: ${ENG_AZURE_REGION}
  resourceGroupRef:
    name: ${ENG_RESOURCE_GROUP_NAME}
  dnsPrefix: eng-mgmt
  kubernetesVersion: ${ENG_K8S_VERSION}
  enableRBAC: true
  networkProfile:
    networkPlugin: azure
    networkPolicy: calico
    serviceCidr: 10.1.0.0/16
    dnsServiceIP: 10.1.0.10
    dockerBridgeCidr: 172.18.0.1/16
    loadBalancerSku: standard
  identity:
    type: UserAssigned
    userAssignedIdentityRef:
      name: id-eng-management
  agentPoolProfiles:
  - name: systempool
    count: ${ENG_SYSTEM_NODE_COUNT}
    vmSize: ${ENG_SYSTEM_NODE_SIZE}
    mode: System
    enableAutoScaling: true
    minCount: 3
    maxCount: 10
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    nodeLabels:
      cluster-type: management
      environment: eng
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
    azurepolicy:
      enabled: true
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-eng-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-eng
  securityProfile:
    defender:
      enabled: true
    workloadIdentity:
      enabled: true
  oidcIssuerProfile:
    enabled: true
```

### 2. Management Cluster Flux Configuration (deployed on each management cluster)

#### flux-config.yaml
```yaml
apiVersion: fluxcd.controlplane.azure.com/v1beta1
kind: FluxConfiguration
metadata:
  name: ${FLUX_CONFIG_NAME}
  namespace: ${NAMESPACE}
spec:
  clusterRef:
    name: ${CLUSTER_NAME}
  namespace: flux-system
  scope: cluster
  sourceKind: GitRepository
  gitRepository:
    url: ${GIT_REPOSITORY_URL}
    branch: ${GIT_BRANCH}
    repositoryRef:
      name: ${GIT_REPO_NAME}
  kustomizations:
  - name: cluster-config
    path: ${KUSTOMIZATION_PATH}
    prune: true
    dependsOn: []
    timeoutInSeconds: 600
    syncIntervalInSeconds: 300
    retryIntervalInSeconds: 120
    substituteFrom:
    - kind: ConfigMap
      name: ${ENVIRONMENT}-cluster-config
      optional: false
    - kind: Secret
      name: ${ENVIRONMENT}-cluster-secrets
      optional: true
  - name: nap-config
    path: ./environment/${ENVIRONMENT}/napconfiguration/base
    prune: true
    dependsOn:
    - cluster-config
    timeoutInSeconds: 600
    syncIntervalInSeconds: 300
    retryIntervalInSeconds: 120
    substituteFrom:
    - kind: ConfigMap
      name: ${ENVIRONMENT}-nap-config
      optional: false
  suspend: false
```

### 3. ConfigMaps for Environment Variables

#### cluster-config.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT}-cluster-config
  namespace: ${NAMESPACE}
data:
  CLUSTER_NAME: "${ENVIRONMENT}-aks-cluster"
  ENVIRONMENT: "${ENVIRONMENT}"
  AZURE_REGION: "${AZURE_REGION}"
  RESOURCE_GROUP_NAME: "rg-${ENVIRONMENT}-aks"
  NAMESPACE: "aso-${ENVIRONMENT}"
  K8S_VERSION: "1.28.5"
  DNS_PREFIX: "${ENVIRONMENT}-aks"
  SERVICE_CIDR: "10.0.0.0/16"
  DNS_SERVICE_IP: "10.0.0.10"
  DOCKER_BRIDGE_CIDR: "172.17.0.1/16"
  MANAGED_IDENTITY_NAME: "id-${ENVIRONMENT}-aks"
  SYSTEM_NODE_COUNT: "3"
  SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  SYSTEM_MIN_NODES: "3"
  SYSTEM_MAX_NODES: "10"
  LOG_ANALYTICS_WORKSPACE_ID: "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-${ENVIRONMENT}-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-${ENVIRONMENT}"
  GIT_REPOSITORY_URL: "https://github.com/your-org/aks-gitops"
  GIT_BRANCH: "main"
  KUSTOMIZATION_PATH: "./environment/${ENVIRONMENT}/azureserviceoperator/base"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT}-nap-config
  namespace: ${NAMESPACE}
data:
  NODEPOOL_NAME: "${ENVIRONMENT}-user-pool"
  NODEPOOL_COUNT: "2"
  NODEPOOL_VM_SIZE: "Standard_D4s_v3"
  NODEPOOL_MIN_COUNT: "1"
  NODEPOOL_MAX_COUNT: "20"
  WORKLOAD_TYPE: "general"
  NODE_TAINTS: "workload-type=${WORKLOAD_TYPE}:NoSchedule"
  CPU_REQUESTS_LIMIT: "100"
  MEMORY_REQUESTS_LIMIT: "200Gi"
  CPU_LIMITS_LIMIT: "200"
  MEMORY_LIMITS_LIMIT: "400Gi"
  PVC_LIMIT: "50"
  LB_LIMIT: "5"
  KARPENTER_NAMESPACE: "karpenter"
  KARPENTER_VERSION: "v0.32.0"
---
apiVersion: v1
kind: Secret
metadata:
  name: ${ENVIRONMENT}-cluster-secrets
  namespace: ${NAMESPACE}
type: Opaque
data:
  SUBSCRIPTION_ID: ${BASE64_SUBSCRIPTION_ID}
  TENANT_ID: ${BASE64_TENANT_ID}
  CLIENT_ID: ${BASE64_CLIENT_ID}
  CLIENT_SECRET: ${BASE64_CLIENT_SECRET}
```

#### management-cluster-config.yaml (for master management cluster)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: management-clusters-config
  namespace: aso-master
data:
  # ENG Management Cluster
  ENG_CLUSTER_NAME: "eng-management-cluster"
  ENG_AZURE_REGION: "eastus"
  ENG_RESOURCE_GROUP_NAME: "rg-eng-management"
  ENG_K8S_VERSION: "1.28.5"
  ENG_SYSTEM_NODE_COUNT: "3"
  ENG_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # DEV Management Cluster
  DEV_CLUSTER_NAME: "dev-management-cluster"
  DEV_AZURE_REGION: "eastus"
  DEV_RESOURCE_GROUP_NAME: "rg-dev-management"
  DEV_K8S_VERSION: "1.28.5"
  DEV_SYSTEM_NODE_COUNT: "3"
  DEV_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # PREPROD Management Cluster
  PREPROD_CLUSTER_NAME: "preprod-management-cluster"
  PREPROD_AZURE_REGION: "eastus"
  PREPROD_RESOURCE_GROUP_NAME: "rg-preprod-management"
  PREPROD_K8S_VERSION: "1.28.5"
  PREPROD_SYSTEM_NODE_COUNT: "3"
  PREPROD_SYSTEM_NODE_SIZE: "Standard_D4s_v3"
  
  # PROD Management Cluster
  PROD_CLUSTER_NAME: "prod-management-cluster"
  PROD_AZURE_REGION: "eastus"
  PROD_RESOURCE_GROUP_NAME: "rg-prod-management"
  PROD_K8S_VERSION: "1.28.5"
  PROD_SYSTEM_NODE_COUNT: "5"
  PROD_SYSTEM_NODE_SIZE: "Standard_D8s_v3"
```

### 4. NAP Configuration (Node Pools deployed from NAP configuration folder)

#### Node Pools (deployed separately from NAP configuration)
```yaml
# napconfiguration/base/nodepools/user-nodepool.yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedClustersAgentPool
metadata:
  name: ${NODEPOOL_NAME}
  namespace: ${NAMESPACE}
spec:
  azureName: ${NODEPOOL_NAME}
  owner:
    name: ${CLUSTER_NAME}
  count: ${NODEPOOL_COUNT}
  vmSize: ${NODEPOOL_VM_SIZE}
  mode: User
  enableAutoScaling: true
  minCount: ${NODEPOOL_MIN_COUNT}
  maxCount: ${NODEPOOL_MAX_COUNT}
  enableNodePublicIP: false
  enableEncryptionAtHost: true
  nodeTaints:
  - ${NODE_TAINTS}
  nodeLabels:
    workload-type: ${WORKLOAD_TYPE}
    environment: ${ENVIRONMENT}
    managed-by: nap
    nodepool-type: user
---
# napconfiguration/base/nodepools/spot-nodepool.yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedClustersAgentPool
metadata:
  name: ${SPOT_NODEPOOL_NAME}
  namespace: ${NAMESPACE}
spec:
  azureName: ${SPOT_NODEPOOL_NAME}
  owner:
    name: ${CLUSTER_NAME}
  count: ${SPOT_NODEPOOL_COUNT}
  vmSize: ${SPOT_NODEPOOL_VM_SIZE}
  mode: User
  enableAutoScaling: true
  minCount: ${SPOT_NODEPOOL_MIN_COUNT}
  maxCount: ${SPOT_NODEPOOL_MAX_COUNT}
  enableNodePublicIP: false
  enableEncryptionAtHost: true
  scaleSetPriority: Spot
  scaleSetEvictionPolicy: Delete
  spotMaxPrice: ${SPOT_MAX_PRICE}
  nodeTaints:
  - spot=true:NoSchedule
  nodeLabels:
    workload-type: spot
    environment: ${ENVIRONMENT}
    managed-by: nap
    nodepool-type: spot
    kubernetes.azure.com/scalesetpriority: spot
---

#### Karpenter Node Provisioning
```yaml
# napconfiguration/base/nodeprovisioning/karpenter-nodeclass.yaml
apiVersion: karpenter.sh/v1beta1
kind: AKSNodeClass
metadata:
  name: ${ENVIRONMENT}-nodeclass
spec:
  imageFamily: AzureLinux
  subnetSelectorTerms:
  - tags:
      environment: ${ENVIRONMENT}
      karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelectorTerms:
  - tags:
      environment: ${ENVIRONMENT}
      karpenter.sh/discovery: ${CLUSTER_NAME}
  userData: |
    #!/bin/bash
    echo "Environment: ${ENVIRONMENT}" >> /etc/kubernetes/kubelet/kubelet-config.json
    echo "NodeClass: ${ENVIRONMENT}-nodeclass" >> /etc/kubernetes/kubelet/kubelet-config.json
---
# napconfiguration/base/nodeprovisioning/karpenter-nodepool.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: ${ENVIRONMENT}-nodepool
spec:
  template:
    metadata:
      labels:
        environment: ${ENVIRONMENT}
        managed-by: karpenter
        cluster-name: ${CLUSTER_NAME}
    spec:
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3"]
      nodeClassRef:
        apiVersion: karpenter.sh/v1beta1
        kind: AKSNodeClass
        name: ${ENVIRONMENT}-nodeclass
      taints:
      - key: workload-type
        value: ${WORKLOAD_TYPE}
        effect: NoSchedule
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
```

### 5. Kyverno Policies (Simplified - Focus on Namespace Labeling)

#### namespace-labeling-policies.yaml
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-namespace-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-environment-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
    validate:
      message: "Namespace must have environment label"
      pattern:
        metadata:
          labels:
            environment: "?*"
  - name: require-workload-type-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
    validate:
      message: "Namespace must have workload-type label"
      pattern:
        metadata:
          labels:
            workload-type: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-pod-tolerations
spec:
  background: true
  rules:
  - name: add-tolerations-based-on-namespace
    match:
      any:
      - resources:
          kinds:
          - Pod
    generate:
      apiVersion: v1
      kind: Pod
      synchronize: true
      data:
        spec:
          tolerations:
          - key: workload-type
            operator: Equal
            value: "{{request.namespace.metadata.labels.workload-type}}"
            effect: NoSchedule
```

## Semantic Versioning with Flux

### Overview
Flux v2 supports semantic versioning (semver) in GitRepository sources, allowing you to create platform releases and separate non-prod and prod clusters with better deployment control. This enables automatic synchronization based on semantic version ranges instead of static branches or tags.

### Environment-Specific Semver Strategy

#### Development/Engineering Environment
- **Semver Range**: `>=0.1.0 <1.0.0` (Pre-release versions)
- **Purpose**: Latest development builds and features
- **Auto-deployment**: Yes, for rapid iteration

#### Staging/Pre-production Environment  
- **Semver Range**: `>=1.0.0-rc <1.0.0` (Release candidates)
- **Purpose**: Release candidate testing
- **Auto-deployment**: Yes, for validation

#### Production Environment
- **Semver Range**: `>=1.0.0 <2.0.0` (Stable releases only)
- **Purpose**: Production-ready stable releases
- **Auto-deployment**: Controlled, with approval gates

### GitRepository Configuration with Semver

#### Development Environment Git Repository
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-dev
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=0.1.0 <1.0.0"
  secretRef:
    name: flux-git-auth
```

#### Staging Environment Git Repository  
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-staging
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=1.0.0-rc <1.0.0"
  secretRef:
    name: flux-git-auth
```

#### Production Environment Git Repository
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-prod
  namespace: flux-system
spec:
  interval: 30m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=1.0.0 <2.0.0"
  secretRef:
    name: flux-git-auth
```

### Kustomization with Environment-Specific Sources

#### Engineering Environment Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: eng-cluster-config
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-dev
  path: "./environment/eng"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: eng-cluster-config
    optional: false
  - kind: ConfigMap
    name: eng-nap-config
    optional: false
  timeout: 10m
```

#### Production Environment Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: prod-cluster-config
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-prod
  path: "./environment/prod"
  prune: true
  substituteFrom:
  - kind: ConfigMap
    name: prod-cluster-config
    optional: false
  - kind: ConfigMap
    name: prod-nap-config
    optional: false
  timeout: 20m
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: azure-service-operator
    namespace: azureserviceoperator-system
```

### Release Workflow with Semver

#### Version Tagging Strategy
```bash
# Development releases (frequent)
git tag v0.1.0    # Initial development
git tag v0.1.1    # Development patches
git tag v0.2.0    # New development features

# Release candidates (staging)
git tag v1.0.0-rc.1    # First release candidate
git tag v1.0.0-rc.2    # Second release candidate

# Production releases (stable)
git tag v1.0.0    # Production release
git tag v1.0.1    # Production patch
git tag v1.1.0    # Production minor release
git tag v2.0.0    # Production major release
```

### Advanced Semver Configurations

#### Pre-release Pattern Matching
```yaml
# For alpha releases in development
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-alpha
  namespace: flux-system
spec:
  interval: 2m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: ">=0.1.0-alpha <1.0.0"
```

#### Hotfix Releases for Production
```yaml
# For emergency hotfixes
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-hotfix
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aks-gitops
  ref:
    semver: "~1.0.0"  # Only patch versions of 1.0.x
```

### Pipeline Structure

```yaml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    include:
    - environment/*

variables:
- group: aks-deployment-variables
- name: vmImageName
  value: 'ubuntu-latest'

stages:
- stage: Validate
  displayName: 'Validation Stage'
  jobs:
  - job: YAMLValidation
    displayName: 'YAML Validation and Linting'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: YamlLint@1
      displayName: 'YAML Lint Check'
      inputs:
        yamlPath: 'environment/'
        configPath: '.yamllint.yml'
        
    - script: |
        # Install kubeval for Kubernetes YAML validation
        curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz
        sudo mv kubeval /usr/local/bin
        
        # Validate all Kubernetes YAML files
        find environment/ -name "*.yaml" -type f | xargs kubeval --strict
      displayName: 'Kubernetes YAML Validation'
      
    - script: |
        # Install kustomize
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        
        # Build and validate kustomizations
        for env in eng dev preprod prod; do
          echo "Validating $env environment"
          kustomize build environment/$env/azureserviceoperator/base/cluster --dry-run
          kustomize build environment/$env/napconfiguration/base --dry-run
        done
      displayName: 'Kustomize Build Validation'

- stage: SecurityScanning
  displayName: 'Security Scanning'
  dependsOn: Validate
  jobs:
  - job: PolicyValidation
    displayName: 'Policy and Security Validation'
    pool:
      vmImage: $(vmImageName)
    steps:
    - script: |
        # Install conftest for policy testing
        wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
        tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
        sudo mv conftest /usr/local/bin
        
        # Run policy tests against YAML files
        conftest verify --policy policies/ environment/
      displayName: 'Policy Validation with Conftest'
      
    - script: |
        # Install kube-score for security analysis
        wget https://github.com/zegl/kube-score/releases/download/v1.16.1/kube-score_1.16.1_linux_amd64.tar.gz
        tar xzf kube-score_1.16.1_linux_amd64.tar.gz
        sudo mv kube-score /usr/local/bin
        
        # Analyze configurations for security issues
        find environment/ -name "*.yaml" -type f | xargs kube-score score
      displayName: 'Security Analysis with kube-score'

- stage: DryRun
  displayName: 'Dry Run Deployment'
  dependsOn: SecurityScanning
  jobs:
  - job: DryRunDeployment
    displayName: 'Dry Run ASO Deployment'
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: KubectlInstaller@0
      displayName: 'Install kubectl'
      
    - script: |
        # Simulate Flux substitution for dry run
        for env in eng dev preprod prod; do
          echo "Dry run for $env environment"
          
          # Create temporary directory for processed files
          mkdir -p /tmp/dry-run/$env
          
          # Process templates with environment variables
          envsubst < environment/$env/azureserviceoperator/base/cluster/aks-cluster.yaml > /tmp/dry-run/$env/aks-cluster.yaml
          
          # Validate processed YAML against Kubernetes API (dry-run)
          kubectl apply --dry-run=client -f /tmp/dry-run/$env/aks-cluster.yaml
        done
      displayName: 'Dry Run Deployment Validation'
      env:
        CLUSTER_NAME: 'test-cluster'
        ENVIRONMENT: 'test'
        AZURE_REGION: 'eastus'
        RESOURCE_GROUP_NAME: 'rg-test'
        NAMESPACE: 'aso-test'

- stage: Deploy
  displayName: 'Deployment Stage'
  dependsOn: DryRun
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployToManagementCluster
    displayName: 'Deploy to Management Cluster'
    environment: 'aks-management-cluster'
    pool:
      vmImage: $(vmImageName)
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: 'Apply ASO Configurations'
            inputs:
              action: 'deploy'
              manifests: |
                environment/$(ENVIRONMENT)/azureserviceoperator/base/**/*.yaml
              namespace: 'aso-$(ENVIRONMENT)'
```

## Security and Access Control

### Master Management Cluster Security

#### RBAC Configuration
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: master-management-cluster-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: master-management-cluster-admin-binding
subjects:
- kind: Group
  name: aks-platform-admins
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: master-management-cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: management-cluster-operator
rules:
- apiGroups: ["containerservice.azure.com"]
  resources: ["managedclusters", "managedclustersagentpools"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["fluxcd.controlplane.azure.com"]
  resources: ["fluxconfigurations"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

#### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: aso-master
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-aso-operator
  namespace: aso-master
spec:
  podSelector:
    matchLabels:
      app: azure-service-operator
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: flux-system
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
```

### Monitoring and Alerting

#### Critical Alerts Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: master-cluster-alerts
  namespace: monitoring
data:
  alerts.yaml: |
    groups:
    - name: master-management-cluster
      rules:
      - alert: MasterClusterDown
        expr: up{job="kubernetes-nodes"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Master management cluster is down"
          description: "The master management cluster has been down for more than 1 minute"
          
      - alert: ASOOperatorDown
        expr: up{job="azure-service-operator"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "ASO Operator is down"
          description: "Azure Service Operator has been down for more than 2 minutes"
          
      - alert: FluxReconciliationFailed
        expr: gotk_reconcile_condition{type="Ready",status="False"} == 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Flux reconciliation failed"
          description: "Flux reconciliation has been failing for {{ $labels.name }}"
```

## Testing Strategy

### 1. Unit Tests for YAML Validation

```bash
#!/bin/bash
# yaml-validation-tests.sh

echo "Running YAML validation tests..."

# Test 1: YAML syntax validation
echo "Test 1: YAML syntax validation"
for file in $(find environment/ -name "*.yaml"); do
    if ! yamllint "$file"; then
        echo "FAIL: $file has syntax errors"
        exit 1
    fi
done
echo "PASS: All YAML files have valid syntax"

# Test 2: Kubernetes resource validation
echo "Test 2: Kubernetes resource validation"
for file in $(find environment/ -name "*.yaml"); do
    if ! kubeval "$file"; then
        echo "FAIL: $file has invalid Kubernetes resources"
        exit 1
    fi
done
echo "PASS: All Kubernetes resources are valid"

# Test 3: Kustomization build tests
echo "Test 3: Kustomization build tests"
for env in eng dev preprod prod; do
    if ! kustomize build "environment/$env/azureserviceoperator/base/cluster"; then
        echo "FAIL: Kustomization build failed for $env"
        exit 1
    fi
done
echo "PASS: All kustomizations build successfully"
```

### 2. Integration Tests

```bash
#!/bin/bash
# integration-tests.sh

echo "Running integration tests..."

# Test 1: Flux substitution test
echo "Test 1: Testing Flux variable substitution"
test_substitution() {
    local env=$1
    export CLUSTER_NAME="test-${env}-cluster"
    export ENVIRONMENT="$env"
    export AZURE_REGION="eastus"
    
    # Process template
    envsubst < "environment/$env/azureserviceoperator/base/cluster/aks-cluster.yaml" > "/tmp/test-$env.yaml"
    
    # Verify substitution worked
    if grep -q '${' "/tmp/test-$env.yaml"; then
        echo "FAIL: Variable substitution incomplete for $env"
        return 1
    fi
    
    # Validate processed YAML
    if ! kubeval "/tmp/test-$env.yaml"; then
        echo "FAIL: Processed YAML invalid for $env"
        return 1
    fi
    
    echo "PASS: Variable substitution successful for $env"
}

for env in eng dev preprod prod; do
    test_substitution "$env"
done

# Test 2: Policy validation
echo "Test 2: Testing Kyverno policies"
conftest verify --policy policies/ environment/

echo "All integration tests completed"
```

### 3. End-to-End Testing

```bash
#!/bin/bash
# e2e-tests.sh

echo "Running end-to-end tests..."

# Test 1: Deploy test cluster
echo "Test 1: Deploying test cluster"
kubectl apply -f test-manifests/test-cluster.yaml
kubectl wait --for=condition=Ready managedcluster/test-cluster --timeout=1200s

# Test 2: Verify NAP functionality
echo "Test 2: Testing Node Auto Provisioning"
kubectl apply -f test-manifests/test-workload.yaml
kubectl wait --for=condition=Ready pod/test-workload --timeout=600s

# Test 3: Verify Kyverno policies
echo "Test 3: Testing Kyverno policy enforcement"
if kubectl apply -f test-manifests/privileged-pod.yaml 2>&1 | grep -q "denied"; then
    echo "PASS: Kyverno policy correctly denied privileged pod"
else
    echo "FAIL: Kyverno policy did not deny privileged pod"
    exit 1
fi

# Cleanup
kubectl delete -f test-manifests/test-cluster.yaml
kubectl delete -f test-manifests/test-workload.yaml

echo "All end-to-end tests completed successfully"
```

## Deployment Workflow

### 1. Pre-deployment Checklist

- [ ] YAML syntax validation passed
- [ ] Kubernetes resource validation passed
- [ ] Kustomization builds successful
- [ ] Security policies validated
- [ ] Dry run deployment successful
- [ ] Environment-specific variables configured
- [ ] RBAC permissions verified
- [ ] Network policies applied
- [ ] Monitoring and alerting configured

### 2. Deployment Process

1. **Master Management Cluster Deployment**
   - Deploy via ARM template
   - Install ASO operator
   - Configure Flux for management cluster deployments
   - Create ConfigMaps with management cluster configurations
   - Apply security policies
   - Verify cluster health

2. **Environment Management Clusters (deployed via ASO from master)**
   - Master management cluster deploys management clusters using ASO
   - Management clusters automatically get ASO operator installed
   - Configure Flux with environment-specific ConfigMaps using `substituteFrom`
   - Apply NAP configuration from dedicated folder
   - Install Kyverno
   - Verify cluster health

3. **Worker Clusters (deployed via ASO from management clusters)**
   - Deploy via ASO from respective management clusters
   - Apply NAP node pools from NAP configuration folder
   - Configure Kyverno policies using `substituteFrom`
   - Verify application readiness

### 3. Rollback Strategy

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rollback-procedures
data:
  rollback.sh: |
    #!/bin/bash
    # Emergency rollback procedure
    
    echo "Initiating rollback procedure..."
    
    # Step 1: Suspend Flux reconciliation
    kubectl patch gitrepository aks-gitops -n flux-system --type='merge' -p='{"spec":{"suspend":true}}'
    
    # Step 2: Rollback to previous known good state
    kubectl apply -f backup-manifests/last-known-good/
    
    # Step 3: Verify cluster health
    kubectl get nodes
    kubectl get pods -A
    
    # Step 4: Re-enable Flux if rollback successful
    if [ $? -eq 0 ]; then
        kubectl patch gitrepository aks-gitops -n flux-system --type='merge' -p='{"spec":{"suspend":false}}'
        echo "Rollback completed successfully"
    else
        echo "Rollback failed - manual intervention required"
        exit 1
    fi
```

## Monitoring and Maintenance

### Health Checks

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: health-check-scripts
data:
  cluster-health.sh: |
    #!/bin/bash
    # Comprehensive cluster health check
    
    echo "=== Cluster Health Check ==="
    
    # Check node status
    echo "Node Status:"
    kubectl get nodes -o wide
    
    # Check system pods
    echo "System Pods Status:"
    kubectl get pods -n kube-system
    
    # Check ASO operator
    echo "ASO Operator Status:"
    kubectl get pods -n azureserviceoperator-system
    
    # Check Flux status
    echo "Flux Status:"
    kubectl get gitrepositories,kustomizations -n flux-system
    
    # Check Kyverno status
    echo "Kyverno Status:"
    kubectl get pods -n kyverno
    
    # Check cluster resources
    echo "Cluster Resource Usage:"
    kubectl top nodes
    kubectl top pods -A
    
    # Check for failed reconciliations
    echo "Failed Reconciliations:"
    kubectl get kustomizations -A -o json | jq '.items[] | select(.status.conditions[]?.status == "False") | .metadata.name'
```

This comprehensive deployment plan provides a robust foundation for managing AKS clusters using ASO, NAP, and Kyverno with proper security, testing, and operational procedures.