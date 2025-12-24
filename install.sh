#!/bin/bash
set -e

# ==============================================================================
# Erxes Next (OS) Deployment Orchestrator
# ==============================================================================
# This script manages the full lifecycle deployment of the Erxes Next stack.
# It enforces idempotency, validates prerequisites, manages secure key generation,
# and handles the container orchestration via Docker Compose.
#
# Usage: ./install.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Output Formatting Utilities
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
step_verify_environment() {
    print_status "Verifying runtime environment..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker engine is not installed. Manual installation required."
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Manual installation required."
        exit 1
    fi

    print_status "Environment validation successful."
}

# ------------------------------------------------------------------------------
# Security & Persistence Layer Provisioning
# ------------------------------------------------------------------------------
step_provision_dependencies() {
    print_status "Provisioning security assets and persistence volumes..."

    # Ensure persistence directories exist
    mkdir -p data/db
    mkdir -p data/redis
    mkdir -p mongo-key

    # Generate MongoDB Keyfile for Replica Set Authentication
    # This keyfile acts as a shared secret between Mongo nodes.
    # We enforce 400 permissions to strict read-only access for the owner (root).
    if [ ! -f mongo-key/mongo-key ]; then
        print_status "Generating secure MongoDB keyfile..."
        openssl rand -base64 756 > mongo-key/mongo-key
        chmod 400 mongo-key/mongo-key
        # Note: In production, ensure the file ownership aligns with the container user ID (999:999).
        # For this setup, we rely on the container entrypoint handling.
    else 
        print_status "MongoDB keyfile already exists. Skipping generation."
    fi
    
    # Create an empty permissions file if required by volume mounts (future proofing)
    if [ ! -f permissions.json ]; then
        echo "{}" > permissions.json
    fi
}

# ------------------------------------------------------------------------------
# Network Orchestration
# ------------------------------------------------------------------------------
step_orchestrate_network() {
    print_status "Configuring Docker network..."
    
    # Check for existing network to prevent 'already exists' errors
    if ! docker network ls | grep -q "erxes"; then
        docker network create erxes
        print_status "Network 'erxes' created."
    else
        print_status "Network 'erxes' already active."
    fi
}

# ------------------------------------------------------------------------------
# Stack Deployment
# ------------------------------------------------------------------------------
step_deploy_stack() {
    print_status "Deploying Erxes Next stack..."
    
    # Explicitly pulling latest images to ensure fresh state
    docker compose pull
    
    # Deploy in detached mode
    docker compose up -d
}

# ------------------------------------------------------------------------------
# Database Initialization
# ------------------------------------------------------------------------------
step_initialize_database() {
    print_status "Initializing MongoDB Replica Set configuration..."
    print_status "Waiting 15s for database process warm-up..."
    sleep 15
    
    # Initialize the Replica Set (rs0).
    # This is critical for OpLog tailing, which enables reactivity in the Platform.
    # We attempt the initiation and suppress errors if it's already initialized.
    if docker exec mongo mongo -u erxes -p your_mongo_password --authenticationDatabase admin --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "mongo:27017"}]});' &> /dev/null; then
         print_status "Replica Set initialized successfully."
    else
         print_status "Replica Set initialization skipped (likely already active)."
    fi
}

# ------------------------------------------------------------------------------
# Main Execution Flow
# ------------------------------------------------------------------------------
main() {
    step_verify_environment
    step_provision_dependencies
    step_orchestrate_network
    step_deploy_stack
    step_initialize_database

    print_status "Deployment sequence completed successfully."
    print_status "Access Dashboard: http://localhost:3000"
    print_status "Access Gateway API: http://localhost"
}

# Execute Main
main
