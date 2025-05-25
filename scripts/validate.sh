#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

check_tools() {
    local missing_tools=()
    
    if ! command -v kustomize &> /dev/null; then
        missing_tools+=("kustomize")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v yamllint &> /dev/null; then
        missing_tools+=("yamllint")
    fi
    
    if ! command -v flux &> /dev/null; then
        missing_tools+=("flux")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
}

validate_yaml() {
    log "Running YAML lint checks..."
    cd "$REPO_ROOT"
    
    if yamllint -c .yamllint.yml .; then
        log "✓ YAML lint checks passed"
    else
        error "✗ YAML lint checks failed"
    fi
}

validate_kustomize_build() {
    log "Validating Kustomize builds..."
    cd "$REPO_ROOT"
    
    local environments=("dev" "ppe" "prd")
    
    # Validate base
    log "Validating base configuration..."
    if kustomize build base/ > /tmp/base-validation.yaml; then
        log "✓ Base configuration is valid"
    else
        error "✗ Base configuration validation failed"
    fi
    
    # Validate overlays
    for env in "${environments[@]}"; do
        log "Validating $env overlay..."
        if kustomize build "overlays/$env/" > "/tmp/$env-validation.yaml"; then
            log "✓ $env overlay is valid"
        else
            error "✗ $env overlay validation failed"
        fi
    done
}

validate_kubernetes_manifests() {
    log "Validating Kubernetes manifests..."
    cd "$REPO_ROOT"
    
    local environments=("dev" "ppe" "prd")
    
    # Validate base
    log "Validating base Kubernetes resources..."
    if kubectl --dry-run=client apply -f /tmp/base-validation.yaml; then
        log "✓ Base Kubernetes resources are valid"
    else
        error "✗ Base Kubernetes resources validation failed"
    fi
    
    # Validate overlays
    for env in "${environments[@]}"; do
        log "Validating $env Kubernetes resources..."
        if kubectl --dry-run=client apply -f "/tmp/$env-validation.yaml"; then
            log "✓ $env Kubernetes resources are valid"
        else
            error "✗ $env Kubernetes resources validation failed"
        fi
    done
}

validate_flux() {
    log "Validating Flux configurations..."
    cd "$REPO_ROOT"
    
    if flux validate --path=flux/clusters/; then
        log "✓ Flux cluster configurations are valid"
    else
        error "✗ Flux cluster configurations validation failed"
    fi
    
    if flux validate --path=flux/environments/; then
        log "✓ Flux environment configurations are valid"
    else
        error "✗ Flux environment configurations validation failed"
    fi
}

security_scan() {
    log "Running security scan..."
    cd "$REPO_ROOT"
    
    local sensitive_patterns=(
        "password"
        "secret"
        "key"
        "token"
        "apikey"
        "api-key"
        "credential"
    )
    
    local found_issues=false
    
    for pattern in "${sensitive_patterns[@]}"; do
        if grep -ri "$pattern" --include="*.yaml" --include="*.yml" . | grep -v "# yamllint"; then
            log "WARNING: Found potential sensitive information: $pattern"
            found_issues=true
        fi
    done
    
    if [ "$found_issues" = true ]; then
        log "⚠ Security scan found potential issues"
        return 1
    else
        log "✓ Security scan passed"
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/*-validation.yaml
}

main() {
    local skip_security=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-security)
                skip_security=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--skip-security]"
                echo "  --skip-security  Skip security scanning"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    trap cleanup EXIT
    
    log "Starting validation process..."
    
    check_tools
    validate_yaml
    validate_kustomize_build
    validate_kubernetes_manifests
    validate_flux
    
    if [ "$skip_security" = false ]; then
        security_scan || log "⚠ Security scan completed with warnings"
    fi
    
    log "✓ All validations completed successfully"
}

main "$@"