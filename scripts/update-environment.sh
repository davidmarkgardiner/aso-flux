#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] ENVIRONMENT

Update environment variables for ASO GitOps deployment

ARGUMENTS:
    ENVIRONMENT         Target environment (dev|ppe|prd)

OPTIONS:
    -s, --subscription  Azure subscription ID
    -r, --resource-group Resource group name
    -c, --cluster-name  Cluster name
    -l, --location      Azure region
    -v, --vm-size       System node VM size
    -n, --vnet-name     Virtual network name
    -u, --subnet-name   Subnet name
    -i, --identity-name Managed identity name
    -a, --admin-group   Admin group object ID
    -p, --project       Project name
    -t, --cost-center   Cost center
    -e, --security-level Security level
    --service-cidr      Service CIDR range
    --dns-service-ip    DNS service IP
    --pod-cidr          Pod CIDR range
    --dry-run           Show changes without applying them
    -h, --help          Show this help message

EXAMPLES:
    # Update dev environment with new cluster name
    $0 dev --cluster-name aks-dev-new

    # Update production with multiple values
    $0 prd --vm-size Standard_D16s_v3 --security-level high

    # Preview changes without applying
    $0 ppe --cluster-name aks-ppe-test --dry-run
EOF
}

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

validate_environment() {
    local env="$1"
    case "$env" in
        dev|ppe|prd)
            return 0
            ;;
        *)
            error "Invalid environment: $env. Must be one of: dev, ppe, prd"
            ;;
    esac
}

update_kustomization() {
    local env="$1"
    local key="$2"
    local value="$3"
    local dry_run="$4"
    
    local kustomization_file="$REPO_ROOT/overlays/$env/kustomization.yaml"
    
    if [[ ! -f "$kustomization_file" ]]; then
        error "Kustomization file not found: $kustomization_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY RUN: Would update $key=$value in $kustomization_file"
        return
    fi
    
    # Update the literal value in configMapGenerator
    if grep -q "- $key=" "$kustomization_file"; then
        sed -i.bak "s|- $key=.*|- $key=$value|" "$kustomization_file"
        rm "$kustomization_file.bak"
        log "Updated $key=$value in $kustomization_file"
    else
        error "Key $key not found in $kustomization_file"
    fi
}

update_cluster_patch() {
    local env="$1"
    local field="$2"
    local value="$3"
    local dry_run="$4"
    
    local patch_file="$REPO_ROOT/overlays/$env/cluster-patch.yaml"
    
    if [[ ! -f "$patch_file" ]]; then
        error "Cluster patch file not found: $patch_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY RUN: Would update $field=$value in $patch_file"
        return
    fi
    
    case "$field" in
        "vmSize")
            sed -i.bak "s|vmSize: .*|vmSize: $value|" "$patch_file"
            ;;
        "environment")
            sed -i.bak "s|environment: .*|environment: $value|" "$patch_file"
            ;;
        "securityLevel")
            sed -i.bak "s|securityLevel: .*|securityLevel: $value|" "$patch_file"
            ;;
        *)
            error "Unknown field for cluster patch: $field"
            ;;
    esac
    
    rm "$patch_file.bak"
    log "Updated $field=$value in $patch_file"
}

main() {
    local environment=""
    local dry_run="false"
    local updates=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--subscription)
                updates+=("SUBSCRIPTION_ID:$2")
                shift 2
                ;;
            -r|--resource-group)
                updates+=("RESOURCE_GROUP:$2")
                shift 2
                ;;
            -c|--cluster-name)
                updates+=("CLUSTER_NAME:$2")
                shift 2
                ;;
            -l|--location)
                updates+=("LOCATION:$2")
                shift 2
                ;;
            -v|--vm-size)
                updates+=("SYSTEM_NODE_VM_SIZE:$2")
                shift 2
                ;;
            -n|--vnet-name)
                updates+=("VNET_NAME:$2")
                shift 2
                ;;
            -u|--subnet-name)
                updates+=("SUBNET_NAME:$2")
                shift 2
                ;;
            -i|--identity-name)
                updates+=("IDENTITY_NAME:$2")
                shift 2
                ;;
            -a|--admin-group)
                updates+=("ADMIN_GROUP_ID:$2")
                shift 2
                ;;
            -p|--project)
                updates+=("PROJECT_NAME:$2")
                shift 2
                ;;
            -t|--cost-center)
                updates+=("COST_CENTER:$2")
                shift 2
                ;;
            -e|--security-level)
                updates+=("SECURITY_LEVEL:$2")
                shift 2
                ;;
            --service-cidr)
                updates+=("SERVICE_CIDR:$2")
                shift 2
                ;;
            --dns-service-ip)
                updates+=("DNS_SERVICE_IP:$2")
                shift 2
                ;;
            --pod-cidr)
                updates+=("POD_CIDR:$2")
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$environment" ]]; then
                    environment="$1"
                else
                    error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$environment" ]]; then
        error "Environment is required"
    fi
    
    validate_environment "$environment"
    
    if [[ ${#updates[@]} -eq 0 ]]; then
        error "At least one update is required"
    fi
    
    log "Updating $environment environment with ${#updates[@]} changes"
    
    for update in "${updates[@]}"; do
        IFS=':' read -r key value <<< "$update"
        update_kustomization "$environment" "$key" "$value" "$dry_run"
        
        # Also update cluster patch for specific fields
        case "$key" in
            "SYSTEM_NODE_VM_SIZE")
                update_cluster_patch "$environment" "vmSize" "$value" "$dry_run"
                ;;
            "ENVIRONMENT")
                update_cluster_patch "$environment" "environment" "$value" "$dry_run"
                ;;
            "SECURITY_LEVEL")
                update_cluster_patch "$environment" "securityLevel" "$value" "$dry_run"
                ;;
        esac
    done
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY RUN completed. No files were modified."
    else
        log "Environment update completed successfully"
        log "Remember to commit and push changes to trigger GitOps deployment"
    fi
}

main "$@"