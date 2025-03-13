#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROGRESS_FILE=".unibot_install_progress"


UNIBOT_API_KEY=""

# Deployment mode and flags
DEPLOY_MODE="local"
SKIP_BUILD=false

while [ $# -gt 0 ]; do
    case "$1" in
        -unibotapikey|--unibot-api-key)
            if [ -n "$2" ]; then
                UNIBOT_API_KEY="$2"
                shift 2
            else
                error "The -unibotapikey option requires an API key value"
                exit 1
            fi
            ;;
        -k|--kubernetes)
            DEPLOY_MODE="k8s"
            shift
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-unibotapikey|--unibot-api-key <api_key>]"
            echo
            echo "Options:"
            echo "  -unibotapikey, --unibot-api-key    UniBot API key for tenant registration"
            echo "  -k, --kubernetes                    Deploy in Kubernetes mode"
            echo "  -s, --skip-build                    Skip UniBot plugin build and setup"
            echo "  -h, --help                         Show this help message"
            exit 0
            ;;
        *)
            error "Unknown parameter: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done


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
    log "Checking required tools..."
    
    local tools=("git" "tutor" "pip" "openssl")
    
    # Add mode-specific tools
    if [ "$DEPLOY_MODE" = "k8s" ]; then
        tools+=("kubectl")
    else
        tools+=("docker")
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

    if [ "$DEPLOY_MODE" = "k8s" ]; then
        if ! kubectl cluster-info &> /dev/null; then
            error "Cannot connect to Kubernetes cluster"
            error "Please check your kubeconfig and cluster access"
            exit 1
        fi
        log "Successfully connected to Kubernetes cluster"
    else
        if ! docker info &> /dev/null; then
            error "Docker is not running or user lacks permissions"
            error "Start Docker and ensure current user is in the docker group"
            exit 1
        fi
    fi
    
    mark_step_complete "prerequisites"
    success "All required tools are installed"
}

# Plugin check and creation
setup_plugin() {
    log "Setting up UniBot plugin..."
    
    if [ ! -d "plugins" ]; then
        mkdir plugins
    fi
    
    cd plugins || exit 1
    
    if [ ! -d "tutor-unibot" ]; then
        log "Cloning UniBot repository..."
        if ! git clone https://github.com/intela-bot/tutor-unibot.git; then
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
    if ! pip install -e "$(pwd)/tutor-unibot" || ! tutor plugins list >/dev/null 2>&1; then
        error "Failed to install plugin or list plugins"
        exit 1
    fi
    
    if ! tutor plugins list | grep -q "unibot"; then
        log "Activating plugin..."
        if ! tutor plugins enable unibot || ! tutor config save >/dev/null 2>&1; then
            error "Failed to activate plugin or save config"
            exit 1
        fi
    fi
    
    cd ..
    mark_step_complete "plugin_setup"
    success "UniBot plugin successfully configured"

    echo debug sleep
    sleep 30
}

# Build and start containers
build_and_start() {
    log "Building and starting containers..."
    
    if ! is_step_complete "images_built"; then
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
        mark_step_complete "images_built"
    fi
    
    if [ "$DEPLOY_MODE" = "local" ]; then
        log "Starting containers..."
        if ! tutor local launch -I; then
            error "Failed to start local deployment"
            exit 1
        fi
    else
        log "Updating Kubernetes deployments..."
        if ! kubectl patch -k "$(tutor config printroot)/env" --patch "{\"spec\": {\"template\": {\"metadata\": {\"labels\": {\"date\": \"`date +'%Y%m%d-%H%M%S'`\"}}}}}"; then
            error "Failed to patch Kubernetes deployments"
            exit 1
        fi
        
        log "Waiting for LMS pods to restart..."
        if ! kubectl wait --namespace openedx --for=condition=ready pod -l app.kubernetes.io/name=lms --timeout=300s; then
            error "Timeout waiting for LMS pods to become ready"
            exit 1
        fi
        
        log "Verifying plugin availability in Kubernetes..."
        if ! tutor k8s exec lms pip list | grep -q "tutor-unibot"; then
            error "UniBot plugin not found in Kubernetes environment"
            exit 1
        fi
        success "UniBot plugin verified in Kubernetes environment"
    fi
    
    mark_step_complete "containers_started"
    success "Containers successfully started"
}

# OAuth setup
setup_oauth() {
    log "Setting up OAuth..."
    
    local USERNAME="unibot"
    local EMAIL="info@intela.io"
    local OAUTH_APP_NAME="unibot-sso"
    local CREDS_FILE="oauth_credentials.txt"
    
    # Check existing credentials
    if [ -f "$CREDS_FILE" ]; then
        warning "Existing OAuth credentials found"
        read -p "Do you want to create new ones? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            success "Skipping OAuth creation"
            return
        fi
    fi
    
    local CLIENT_ID=$(generate_random_string 16)
    local CLIENT_SECRET=$(generate_random_string 32)
    
    log "Creating/updating user..."
    local cmd="$([[ $DEPLOY_MODE == "k8s" ]] && echo "exec" || echo "run")"
    local RESULT
    if ! RESULT=$(tutor $DEPLOY_MODE $cmd lms ./manage.py lms manage_user $USERNAME $EMAIL --staff --unusable-password 2>&1); then
        error "Failed to create/update user: $RESULT"
        exit 1
    fi
    if echo "$RESULT" | grep -q "Found existing user: \"$USERNAME\""; then
        warning "User $USERNAME already exists, skipping user creation"
        return 0
    fi


    log "Creating OAuth application..."
    if ! RESULT=$(tutor $DEPLOY_MODE $cmd lms ./manage.py lms create_dot_application \
        --grant-type client-credentials \
        --redirect-uris "{% if ENABLE_HTTPS %}https{% else %}http{% endif %}://{{ CMS_HOST }}/complete/edx-oauth2/" \
        --client-id "$CLIENT_ID" \
        --client-secret "$CLIENT_SECRET" \
        --scopes user_id \
        --skip-authorization \
        --update $OAUTH_APP_NAME $USERNAME 2>&1); then
        error "Failed to create OAuth application: $RESULT"
        exit 1
    fi
     
    # Save credentials
    local LMS_HOST MFE_HOST
    if ! LMS_HOST=$(tutor config printvalue LMS_HOST) || ! MFE_HOST=$(tutor config printvalue MFE_HOST); then
        error "Failed to get LMS_HOST or MFE_HOST values"
        exit 1
    fi
    
    {
        echo "OpenEdX OAuth Credentials"
        echo "Generated on: $(date)"
        echo "LMS host: $LMS_HOST"
        echo "MFE host: $MFE_HOST"
        echo "----------------------------------------"
        echo "Client ID: $CLIENT_ID"
        echo "Client Secret: $CLIENT_SECRET"
    } > "$CREDS_FILE"

    log "Registering tenant in meta-admin application..."
    
    local subdomain=$(generate_random_string 10)
    local organization_name=$(tutor config printvalue LMS_HOST)
    local edx_lms_host=$(tutor config printvalue LMS_HOST)
    local edx_mfe_host=$(tutor config printvalue MFE_HOST)
    local availability_zone='asia'
    local distribution_channel='stable' 
    local registration_api_key="$UNIBOT_API_KEY"
    local registration_url='https://unibot-sf.san.systems/meta-admin/api/v1/tenants'

    # Construct JSON payload properly
    local request_body='{
        "subdomain": "'$subdomain'",
        "organization_name": "'$organization_name'",
        "edx_client_id": "'$CLIENT_ID'",
        "edx_client_secret": "'$CLIENT_SECRET'",
        "edx_lms_host": "'$edx_lms_host'",
        "edx_mfe_host": "'$edx_mfe_host'",
        "availability_zone": "'$availability_zone'",
        "distribution_channel": "'$distribution_channel'"
    }'

    # Send request and capture response
    log "Sending registration request..."
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-API-KEY: $registration_api_key" \
        -d "$request_body" \
        "$registration_url")

    # Check if curl request was successful
    if [ $? -ne 0 ]; then
        error "Failed to register tenant. Network or server error."
        exit 1
    fi
    log "Tenant registration completed successfully"
    # Extract values using sed
    local unibot_base_url=$(echo "$response" | sed -n 's/.*"UNIBOT_BASE_URL":"\([^"]*\)".*/\1/p')
    local unibot_api_key=$(echo "$response" | sed -n 's/.*"UNIBOT_API_KEY":"\([^"]*\)".*/\1/p')
    local unibot_jwt_secret_key=$(echo "$response" | sed -n 's/.*"UNIBOT_JWT_SECRET_KEY":"\([^"]*\)".*/\1/p')
    local unibot_widget_url="${unibot_base_url}widget/loader.js"
    local script_tag="<script src=\\\"$unibot_widget_url\\\"></script>"

    local MYSQL_ROOT_PASSWORD="$(tutor config printvalue MYSQL_ROOT_PASSWORD)"
    if ! tutor $DEPLOY_MODE exec \
    mysql sh -c "mysql -u root -p"$MYSQL_ROOT_PASSWORD" -D openedx -e \"INSERT INTO uni_bot_unibotsettingsconfiguration (config_values, change_date, enabled) VALUES ('{
        \\\"UNIBOT_BASE_URL\\\": \\\"$unibot_base_url\\\",
        \\\"API_KEY\\\": \\\"$unibot_jwt_secret_key\\\",
        \\\"UNIBOT_JWT_SECRET_KEY\\\": \\\"$unibot_jwt_secret_key\\\",
        \\\"UNIBOT_API_KEY\\\": \\\"$unibot_api_key\\\"
    }', NOW(), true);
    UPDATE site_configuration_siteconfiguration SET site_values = JSON_SET(site_values, '$.MFE_CONFIG_OVERRIDES', JSON_OBJECT('learning', JSON_OBJECT('EXTERNAL_SCRIPTS', JSON_ARRAY(JSON_OBJECT('isAuthnRequired', true, 'head', '', 'body', JSON_OBJECT('top', '', 'bottom', '$script_tag')))))) WHERE id = 1;\""; then
        error "Failed to update MySQL configuration"
        exit 1
    fi

    # Validate response values
    if [ -z "$unibot_base_url" ] || [ -z "$unibot_api_key" ] || [ -z "$unibot_jwt_secret_key" ]; then
        error "Failed to parse registration response. Missing required values."
        error "Response: $response"
        exit 1
    fi

    # Save UniBot credentials
    {
        echo "UniBot Credentials"
        echo "Generated on: $(date)"
        echo "----------------------------------------"
        echo "Base URL: $unibot_base_url"
        echo "API Key: $unibot_api_key"
        echo "JWT Secret Key: $unibot_jwt_secret_key"
    } >> "$CREDS_FILE"

    success "Tenant registration completed successfully"
}

# Functions for tracking progress
mark_step_complete() {
    echo "$1" >> "$PROGRESS_FILE"
}

is_step_complete() {
    [ -f "$PROGRESS_FILE" ] && grep -q "^$1$" "$PROGRESS_FILE"
}

# Clean progress
clean_progress() {
    if [ -f "$PROGRESS_FILE" ]; then
        rm "$PROGRESS_FILE"
    fi
}

check_interrupted_install() {
    if [ -f "$PROGRESS_FILE" ]; then
        warning "Interrupted installation detected"
        local registration_api_key="$UNIBOT_API_KEY"
        if [ -z "$registration_api_key" ]; then
            error "UniBot API key is required. Please provide it using the -unibotapikey option"
            echo "Example: $0 -unibotapikey your_api_key_here"
            exit 1
        fi
        read -p "Continue from last successful step? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "Starting new installation..."
            clean_progress
        else
            success "Continuing installation..."
        fi
    fi
}

main() {
    echo -e "${BLUE}=== UniBot Installation for OpenEdX ===${NC}"
    echo "Script version: 1.0.0"
    echo "----------------------------------------"
    
    check_interrupted_install
    
    if ! is_step_complete "prerequisites"; then
        check_prerequisites
    fi
    
    if [ "$SKIP_BUILD" = false ]; then
        if ! is_step_complete "plugin_setup"; then
            setup_plugin
        fi
        
        if ! is_step_complete "containers_started"; then
            build_and_start
        fi
    else
        log "Skipping build steps due to --skip-build flag"
    fi
    
    if ! is_step_complete "oauth_setup"; then
        setup_oauth
    fi
    
    success "UniBot installation completed successfully!"
    clean_progress
    tutor $DEPLOY_MODE $([[ $DEPLOY_MODE == "k8s" ]] && echo "reboot" || echo "restart")
}

# Interrupt handling
trap 'error "Installation interrupted by user"; exit 1' INT

# Run script
main
