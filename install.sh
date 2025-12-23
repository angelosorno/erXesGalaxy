#!/bin/bash
set -e

# ==========================================
# 0. Global Setup & Helpers
# ==========================================

log_time() {
    date +'%H:%M:%S'
}

print_step() {
    echo -e "$2 [$(log_time)] $1"
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

print_step "Detected OS: $OS_TYPE" "🖥️"

if [ "$OS_TYPE" == "UNKNOWN" ]; then
    echo "❌ Unsupported OS. This script supports Linux (Ubuntu/Debian) and macOS."
    exit 1
fi

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ .env file not found. Please create one with DOMAIN= and USER_PASSWORD="
  exit 1
fi

if [ -z "$DOMAIN" ]; then
  echo "❌ Missing DOMAIN in .env"
  exit 1
fi

# ==========================================
# 1. System & Dependencies
# ==========================================
step_install_deps() {
    print_step "Step 1: Installing Dependencies" "📦"

    # Update System
    if [ "$OS_TYPE" == "Linux" ]; then
        sudo apt-get update -y
        # Install basics
        sudo apt-get install -y passwd util-linux jq curl software-properties-common
    elif [ "$OS_TYPE" == "Mac" ]; then
        if ! check_cmd brew; then
            echo "❌ Homebrew required. Install from brew.sh"
            exit 1
        fi
        brew update
        check_cmd jq || brew install jq
    fi

    # Install Docker
    if check_cmd docker; then
        print_step "Docker already installed" "✅"
    else
        print_step "Installing Docker..." "🐳"
        if [ "$OS_TYPE" == "Linux" ]; then
             sudo apt-get install apt-transport-https ca-certificates curl -y
             curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
             echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
             sudo apt-get update -y
             sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
        else
             brew install --cask docker
             print_step "⚠️  Start Docker Desktop manually!" "⚠️"
        fi
    fi

    # Install Node
    if check_cmd node; then
         print_step "Node.js already installed" "✅"
    else
         print_step "Installing Node.js..." "🟢"
         if [ "$OS_TYPE" == "Linux" ]; then
            curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
         else
            brew install node
         fi
    fi

    # Install create-erxes-app
    if ! check_cmd create-erxes-app; then
        print_step "Installing create-erxes-app..." "✨"
        sudo npm install -g create-erxes-app
    fi
}

# ==========================================
# 2. App Setup
# ==========================================
step_setup_app() {
    print_step "Step 2: App Setup" "🚀"
    
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    
    if [ -d "$ERXES_DIR" ]; then 
        print_step "Cleaning old directory..." "🧹"
        sudo rm -rf "$ERXES_DIR"
    fi

    print_step "Creating erxes app..." "✨"
    DOMAIN=$DOMAIN create-erxes-app erxes

    cd "$ERXES_DIR" || exit 1

    LATEST_VERSION=$(npm view erxes dist-tags.latest)
    print_step "Updating to version $LATEST_VERSION..." "✏️"
    jq --arg version "$LATEST_VERSION" '.dependencies.erxes = $version' package.json > tmp.json && mv tmp.json package.json
    
    # Add configs
    jq '. + {"essyncer": {}, "elasticsearch": {}}' configs.json > tmp.json && mv tmp.json configs.json

    print_step "Installing npm dependencies..." "📦"
    npm install --loglevel=error
}

# ==========================================
# 3. Swarm Init
# ==========================================
step_init_swarm() {
    print_step "Step 3: Docker Swarm" "🐝"
    
    if ! docker info | grep -q "Swarm: active"; then
        print_step "Initializing Swarm..." "🚀"
        docker swarm init || true
    else
         print_step "Swarm already active" "✅"
    fi

    # Network
    if ! docker network ls | grep -q "erxes"; then
        print_step "Creating 'erxes' network..." "🌐"
        docker network create --driver=overlay --attachable erxes
    fi
}

# ==========================================
# 4. Database Setup
# ==========================================
step_setup_mongo() {
    print_step "Step 4: Database Setup" "🗄️"
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    cd "$ERXES_DIR" || exit 1

    # Keys
    if [ ! -f "mongo-key" ]; then
        print_step "Generating keys..." "🔑"
        openssl rand -base64 756 > mongo-key
        chmod 600 mongo-key
        
        openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem -subj "/CN=localhost" 2>/dev/null
        cat key.pem certificate.pem > mongo.pem
        chmod 600 mongo.pem
    fi

    print_step "Deploying Databases..." "🚀"
    npm run erxes deploy-dbs -- --prefix "$ERXES_DIR" --detach=false

    # Wait for Mongo
    print_step "Waiting for MongoDB..." "⏳"
    until docker ps | grep "mongo"; do sleep 2; done
    sleep 5 

    MONGO_CONTAINER=$(docker ps --filter "name=mongo" --format "{{.Names}}" | head -n 1)
    MONGO_PASSWORD=$(jq -r '.mongo.password' configs.json)
    
    if [ -n "$MONGO_CONTAINER" ] && [ -n "$MONGO_PASSWORD" ]; then
         print_step "Initializing Replica Set..." "⚙️"
         docker exec "$MONGO_CONTAINER" mongo -u erxes -p "$MONGO_PASSWORD" --eval 'rs.initiate()' || true
    fi
}

# ==========================================
# 5. Traefik Integration & Launch
# ==========================================
step_setup_traefik_override() {
    print_step "Step 5: Traefik & Launch" "🚦"
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    cd "$ERXES_DIR" || exit 1

    mkdir -p locales
    
    LATEST_VERSION=$(npm view erxes version)
    jq --arg version "$LATEST_VERSION" '.version = $version' configs.json > tmp.json && mv tmp.json configs.json

    print_step "Generating docker-compose.override.yml..." "📝"
    
    # We create an override file that:
    # 1. Defines the Traefik service
    # 2. Adds labels to Erxes services to route traffic via Traefik
    
    cat <<EOF > docker-compose.override.yml
version: '3.7'

services:
  traefik:
    image: traefik:v3.0
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - erxes
    deploy:
      mode: global
      placement:
        constraints:
          - node.role == manager

  # Frontend (Router: /)
  front:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.front.rule=Host(\`${DOMAIN}\`)"
        - "traefik.http.routers.front.entrypoints=web"
        - "traefik.http.services.front.loadbalancer.server.port=3000"

  # API Gateway (Router: /gateway)
  api:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.api.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/gateway\`)"
        - "traefik.http.routers.api.entrypoints=web"
        - "traefik.http.services.api.loadbalancer.server.port=3300"
        # Middleware to strip prefix if needed, usually erxes expects /gateway/
  
  # Widgets (Router: /widgets)
  widgets:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.widgets.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/widgets\`)"
        - "traefik.http.routers.widgets.entrypoints=web"
        - "traefik.http.services.widgets.loadbalancer.server.port=3200"

  # Integrations (Router: /integrations)
  integrations:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.integrations.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/integrations\`)"
        - "traefik.http.routers.integrations.entrypoints=web"
        - "traefik.http.services.integrations.loadbalancer.server.port=3400"

  # Mobile App (Router: /mobile-app)
  mobile-app:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.mobile-app.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/mobile-app\`)"
        - "traefik.http.routers.mobile-app.entrypoints=web"
        - "traefik.http.services.mobile-app.loadbalancer.server.port=4100"

  # Dashboard Front (Router: /dashboard/front)
  dashboard-front:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard-front.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard/front\`)"
        - "traefik.http.routers.dashboard-front.entrypoints=web"
        - "traefik.http.services.dashboard-front.loadbalancer.server.port=4200"

  # Dashboard API (Router: /dashboard/api)
  dashboard-api:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard-api.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard/api\`)"
        - "traefik.http.routers.dashboard-api.entrypoints=web"
        - "traefik.http.services.dashboard-api.loadbalancer.server.port=4300"

networks:
  erxes:
    external: true
EOF

    print_step "Starting App Stack (with Traefik)..." "🚀"
    # Verify the override file is picked up by default on 'docker stack deploy'
    # usually requires -c docker-compose.yml -c docker-compose.override.yml explicitely if not using 'docker-compose up'
    # npm run erxes up usually just runs docker-compose or similar.
    # To use swarms 'docker stack deploy', we often need to merge files.
    
    # We'll assume npm script uses docker-compose. 
    # If erxes script uses 'docker stack deploy', we need to check how it consumes overrides.
    # Standard docker-compose picks up override automatically.
    
    npm run erxes up -- --uis
}

# ==========================================
# RUN ALL
# ==========================================

step_install_deps
# step_create_user (Removed)
step_setup_app
step_init_swarm
step_setup_mongo
step_setup_traefik_override

print_step "Done! Visit http://$DOMAIN" "🎉"
print_step "Traefik Dashboard: http://$DOMAIN:8080" "🚥"
