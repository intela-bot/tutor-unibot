#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Global variables
DEPLOYMENT_MODE="local"  # Default to local mode
NAMESPACE="openedx"      # Default k8s namespace

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --k8s          Use Kubernetes deployment mode"
    echo "  -n, --namespace    Kubernetes namespace (default: openedx)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run with local Docker deployment"
    echo "  $0 -k              # Run with Kubernetes deployment"
    echo "  $0 -k -n my-ns     # Run with Kubernetes in 'my-ns' namespace"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--k8s)
                DEPLOYMENT_MODE="k8s"
                shift
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

generate_random_string() {
    local length=${1:-32}
    openssl rand -hex "$length"
}

check_prerequisites() {
    log "Checking required tools for $DEPLOYMENT_MODE deployment..."
    
    local tools=("git" "tutor" "pip" "openssl")
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        tools+=("docker")
    else
        tools+=("kubectl")
    fi
    
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install them before running the script"
        exit 1
    fi

    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        if ! docker info &> /dev/null; then
            error "Docker is not running or user lacks permissions"
            error "Start Docker and ensure current user is in the docker group"
            exit 1
        fi
    else
        if ! kubectl cluster-info &> /dev/null; then
            error "Cannot connect to Kubernetes cluster"
            error "Please ensure kubectl is configured and cluster is accessible"
            exit 1
        fi
        log "Connected to Kubernetes cluster"
    fi
    
    success "All required tools are installed and accessible"
}

check_k8s_prerequisites() {
    log "Checking Kubernetes-specific prerequisites..."
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Creating namespace: $NAMESPACE"
        if ! kubectl create namespace "$NAMESPACE"; then
            error "Failed to create namespace: $NAMESPACE"
            exit 1
        fi
    else
        log "Namespace '$NAMESPACE' already exists"
    fi
    
    log "Checking for ingress controller..."
    if ! kubectl get ingressclass &> /dev/null; then
        warning "No ingress controller found. You may need to install one (e.g., nginx-ingress)"
    fi
    
    log "Checking for default storage class..."
    if ! kubectl get storageclass | grep -q "(default)"; then
        warning "No default storage class found. You may need to configure persistent storage"
    fi
    
    success "Kubernetes prerequisites checked"
}

setup_plugin() {
    log "Setting up UniBot plugin..."
    
    if [ ! -d "plugins" ]; then
        mkdir plugins
    fi
    
    cd plugins || exit 1
    
    if [ ! -d "tutor-unibot" ]; then
        log "Cloning UniBot repository..."
        if ! git clone -b custom_widget_in_separate_tab https://github.com/intela-bot/tutor-unibot.git; then
            error "Failed to clone repository"
            exit 1
        fi
    else
        log "Updating UniBot repository..."
        cd tutor-unibot
        git pull
        cd ..
    fi
    
    log "Installing plugin..."
    if ! pip install -e "$(pwd)/tutor-unibot" || ! tutor plugins list; then
        error "Failed to install plugin or list plugins"
        exit 1
    fi
    
    log "Activating plugin..."
    if ! tutor plugins enable unibot || ! tutor config save >/dev/null 2>&1; then
        error "Failed to activate plugin or save config"
        exit 1
    fi
    
    cd ..
    success "UniBot plugin successfully configured"
}

configure_k8s_settings() {
    log "Configuring Kubernetes-specific settings..."
    
    if ! tutor config save --set K8S_NAMESPACE="$NAMESPACE"; then
        error "Failed to set Kubernetes namespace"
        exit 1
    fi
    
    success "Kubernetes settings configured"
}

build_images() {
    log "Building OpenEdX and MFE images for $DEPLOYMENT_MODE deployment..."
    
    if [ "$DEPLOYMENT_MODE" = "k8s" ]; then
        log "Building images for Kubernetes deployment..."
        warning "Note: For production k8s deployments, consider pushing images to a container registry"
    fi
    
    log "Building OpenEdX image..."
    if ! tutor images build openedx --no-cache --no-registry-cache; then
        error "Failed to build OpenEdX image"
        exit 1
    fi
    
    log "Building MFE image..."
    if ! tutor images build mfe --no-cache --no-registry-cache; then
        error "Failed to build MFE image"
        exit 1
    fi
    
    success "Images successfully built"
}

launch_platform() {
    log "Launching OpenEdX platform in $DEPLOYMENT_MODE mode..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        log "Starting local deployment with Docker..."
        if ! tutor local launch -I; then
            error "Failed to launch local deployment"
            exit 1
        fi
    else
        log "Starting Kubernetes deployment..."
        if ! tutor k8s launch -I; then
            error "Failed to launch Kubernetes deployment"
            exit 1
        fi
        
        # Wait for essential pods to be ready (skip problematic ones like elasticsearch)
        log "Waiting for essential pods to be ready in namespace $NAMESPACE..."
        
        local essential_pods=("lms" "cms" "caddy" "mongodb" "mysql" "redis")
        local all_ready=true
        
        for pod_name in "${essential_pods[@]}"; do
            log "Waiting for $pod_name pod to be ready..."
            if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name="$pod_name" -n "$NAMESPACE" --timeout=300s &> /dev/null; then
                success "$pod_name pod is ready"
            else
                warning "$pod_name pod may still be starting, but continuing..."
                all_ready=false
            fi
        done
        
        log "Checking overall pod status..."
        kubectl get pods -n "$NAMESPACE"
        
        local running_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        log "Pod summary: $running_pods/$total_pods pods running"
        
        if [ "$running_pods" -ge 5 ]; then
            success "Enough essential pods are running to proceed"
        else
            warning "Some pods may still be starting, but proceeding with OAuth setup"
        fi
        
        log "Kubernetes services in namespace $NAMESPACE:"
        kubectl get services -n "$NAMESPACE"
        
        if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
            log "Ingress resources in namespace $NAMESPACE:"
            kubectl get ingress -n "$NAMESPACE"
        fi
    fi
    
    success "Platform launched successfully in $DEPLOYMENT_MODE mode"
}

create_oauth_credentials() {
    log "Creating OAuth credentials..."
    
    local USERNAME="unibot"
    local EMAIL="info@intela.io"
    local OAUTH_APP_NAME="unibot-sso"
    
    local CLIENT_ID=$(generate_random_string 16)
    local CLIENT_SECRET=$(generate_random_string 32)
    
    local TUTOR_CMD
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        TUTOR_CMD="tutor local run"
    else
        TUTOR_CMD="tutor k8s exec"
        
        log "Ensuring LMS is ready for management commands..."
        sleep 10
        
        if ! kubectl get pod -l app.kubernetes.io/name=lms -n "$NAMESPACE" | grep -q Running; then
            warning "LMS pod may not be fully ready. Waiting 30 seconds..."
            sleep 30
        fi
    fi
    
    log "Creating/updating user..."
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if $TUTOR_CMD lms ./manage.py lms manage_user $USERNAME $EMAIL --staff --unusable-password; then
            success "User created/updated successfully"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                warning "User creation failed. Retrying in 10 seconds... (attempt $retry_count/$max_retries)"
                sleep 10
            else
                error "Failed to create/update user after $max_retries attempts"
                error "You can manually create the user later with:"
                error "$TUTOR_CMD lms ./manage.py lms manage_user $USERNAME $EMAIL --staff --unusable-password"
                break
            fi
        fi
    done

    log "Creating OAuth application..."
    retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if $TUTOR_CMD lms ./manage.py lms create_dot_application \
            --grant-type client-credentials \
            --redirect-uris "{% if ENABLE_HTTPS %}https{% else %}http{% endif %}://{{ CMS_HOST }}/complete/edx-oauth2/" \
            --client-id "$CLIENT_ID" \
            --client-secret "$CLIENT_SECRET" \
            --scopes user_id \
            --skip-authorization \
            --update $OAUTH_APP_NAME $USERNAME; then
            success "OAuth application created successfully"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                warning "OAuth app creation failed. Retrying in 10 seconds... (attempt $retry_count/$max_retries)"
                sleep 10
            else
                error "Failed to create OAuth application after $max_retries attempts"
                error "You can manually create it later with:"
                error "$TUTOR_CMD lms ./manage.py lms create_dot_application --grant-type client-credentials --client-id \"$CLIENT_ID\" --client-secret \"$CLIENT_SECRET\" --scopes user_id --skip-authorization --update $OAUTH_APP_NAME $USERNAME"
                break
            fi
        fi
    done

    # Get LMS and MFE hosts
    local LMS_HOST MFE_HOST
    if ! LMS_HOST=$(tutor config printvalue LMS_HOST) || ! MFE_HOST=$(tutor config printvalue MFE_HOST); then
        warning "Failed to get LMS_HOST or MFE_HOST values, using defaults"
        LMS_HOST="local.edly.io"
        MFE_HOST="apps.local.edly.io"
    fi

    echo -e "\n${GREEN}OpenEdX Configuration (${DEPLOYMENT_MODE} mode):${NC}"
    echo -e "LMS Host: ${BLUE}$LMS_HOST${NC}"
    echo -e "MFE Host: ${BLUE}$MFE_HOST${NC}"
    if [ "$DEPLOYMENT_MODE" = "k8s" ]; then
        echo -e "Namespace: ${BLUE}$NAMESPACE${NC}"
    fi
    echo -e "\n${GREEN}OAuth Credentials:${NC}"
    echo -e "Client ID: ${BLUE}$CLIENT_ID${NC}"
    echo -e "Client Secret: ${BLUE}$CLIENT_SECRET${NC}"
    
    # Write credentials to file
    log "Writing credentials to credentials.txt..."
    cat > credentials.txt << EOF
OpenEdX Configuration ($DEPLOYMENT_MODE mode):
LMS Host: $LMS_HOST
MFE Host: $MFE_HOST$([ "$DEPLOYMENT_MODE" = "k8s" ] && echo -e "\nNamespace: $NAMESPACE")

OAuth Credentials:
Client ID: $CLIENT_ID
Client Secret: $CLIENT_SECRET
EOF
    success "Credentials written to credentials.txt"
}

main() {
    echo -e "${BLUE}=== UniBot Installation Script ===${NC}"
    echo -e "${BLUE}Deployment Mode: ${YELLOW}$DEPLOYMENT_MODE${NC}"
    if [ "$DEPLOYMENT_MODE" = "k8s" ]; then
        echo -e "${BLUE}Kubernetes Namespace: ${YELLOW}$NAMESPACE${NC}"
    fi
    echo ""
    
    check_prerequisites
    
    if [ "$DEPLOYMENT_MODE" = "k8s" ]; then
        check_k8s_prerequisites
        configure_k8s_settings
    fi
    
    setup_plugin
    build_images
    launch_platform
    create_oauth_credentials
    
    success "Script completed successfully in $DEPLOYMENT_MODE mode!"
}

# Interrupt handling
trap 'error "Installation interrupted by user"; exit 1' INT

# Parse arguments and run script
parse_arguments "$@"
main