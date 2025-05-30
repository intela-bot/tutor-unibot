#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    
    local tools=("git" "tutor" "pip" "openssl" "docker")
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

    if ! docker info &> /dev/null; then
        error "Docker is not running or user lacks permissions"
        error "Start Docker and ensure current user is in the docker group"
        exit 1
    fi
    
    success "All required tools are installed"
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

build_images() {
    log "Building OpenEdX and MFE images..."
    
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

create_oauth_credentials() {
    log "Creating OAuth credentials..."
    
    local USERNAME="unibot"
    local EMAIL="info@intela.io"
    local OAUTH_APP_NAME="unibot-sso"
    
    local CLIENT_ID=$(generate_random_string 16)
    local CLIENT_SECRET=$(generate_random_string 32)
    
    log "Creating/updating user..."
    if ! tutor local run lms ./manage.py lms manage_user $USERNAME $EMAIL --staff --unusable-password; then
        error "Failed to create/update user"
        exit 1
    fi

    log "Creating OAuth application..."
    if ! tutor local run lms ./manage.py lms create_dot_application \
        --grant-type client-credentials \
        --redirect-uris "{% if ENABLE_HTTPS %}https{% else %}http{% endif %}://{{ CMS_HOST }}/complete/edx-oauth2/" \
        --client-id "$CLIENT_ID" \
        --client-secret "$CLIENT_SECRET" \
        --scopes user_id \
        --skip-authorization \
        --update $OAUTH_APP_NAME $USERNAME; then
        error "Failed to create OAuth application"
        exit 1
    fi

    # Get LMS and MFE hosts
    local LMS_HOST MFE_HOST
    if ! LMS_HOST=$(tutor config printvalue LMS_HOST) || ! MFE_HOST=$(tutor config printvalue MFE_HOST); then
        error "Failed to get LMS_HOST or MFE_HOST values"
        exit 1
    fi

    echo -e "\n${GREEN}OpenEdX Configuration:${NC}"
    echo -e "LMS Host: ${BLUE}$LMS_HOST${NC}"
    echo -e "MFE Host: ${BLUE}$MFE_HOST${NC}"
    echo -e "\n${GREEN}OAuth Credentials:${NC}"
    echo -e "Client ID: ${BLUE}$CLIENT_ID${NC}"
    echo -e "Client Secret: ${BLUE}$CLIENT_SECRET${NC}"
    
    # Write credentials to file
    log "Writing credentials to credentials.txt..."
    cat > credentials.txt << EOF
OpenEdX Configuration:
LMS Host: $LMS_HOST
MFE Host: $MFE_HOST

OAuth Credentials:
Client ID: $CLIENT_ID
Client Secret: $CLIENT_SECRET
EOF
    success "Credentials written to credentials.txt"
}

main() {
    echo -e "${BLUE}=== UniBot Installation Script ===${NC}"
    
    check_prerequisites
    setup_plugin
    build_images
    tutor local launch -I
    create_oauth_credentials
    
    success "Script completed successfully!"
}

# Interrupt handling
trap 'error "Installation interrupted by user"; exit 1' INT

# Run script
main