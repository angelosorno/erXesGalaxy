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

OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

print_step "Detected OS: $OS_TYPE" "🖥️"

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
        sudo apt-get install -y passwd util-linux jq curl software-properties-common git
    elif [ "$OS_TYPE" == "Mac" ]; then
        if ! check_cmd brew; then
            echo "❌ Homebrew required. Install from brew.sh"
            exit 1
        fi
        brew update
        check_cmd jq || brew install jq
    fi

    # Docker
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

    # Node.js (v20 for Erxes v3)
    if check_cmd node; then
         # Check version roughly? Skip for simplicity if present.
         print_step "Node.js already installed" "✅"
    else
         print_step "Installing Node.js v20..." "🟢"
         if [ "$OS_TYPE" == "Linux" ]; then
            curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
         else
            brew install node@20
            brew link node@20
         fi
    fi
}

# ==========================================
# 2. Clone & Setup Erxes
# ==========================================
step_setup_app() {
    print_step "Step 2: Cloning Erxes (v3/Latest)" "🐙"
    
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    
    if [ -d "$ERXES_DIR" ]; then 
        print_step "Directory $ERXES_DIR exists..." "📂"
        # Optional: pull latest?
        cd "$ERXES_DIR"
        git pull origin master || git pull origin main
    else
        print_step "Cloning repository..." "⬇️"
        git clone https://github.com/erxes/erxes.git "$ERXES_DIR"
        cd "$ERXES_DIR"
    fi

    # Ensure configs exists
    if [ ! -f "configs.json" ]; then
         print_step "Creating default configs.json..." "⚙️"
         echo '{}' > configs.json
         # Add basic structure if needed, or rely on internal defaults?
         # Previous script added:
         jq '. + {"essyncer": {}, "elasticsearch": {}}' configs.json > tmp.json && mv tmp.json configs.json
    fi
    
    # .env setup inside erxes if needed
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
        else
            touch .env
        fi
    fi
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

    if ! docker network ls | grep -q "erxes"; then
        print_step "Creating 'erxes' network..." "🌐"
        docker network create --driver=overlay --attachable erxes
    fi
}

# ==========================================
# 4. Traefik Override
# ==========================================
step_setup_traefik_override() {
    print_step "Step 4: Traefik & Routing" "🚦"
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    cd "$ERXES_DIR" || exit 1

    print_step "Generating docker-compose.override.yml..." "📝"
    
    # We attempt to guess service names from standard usage, 
    # but since this is a fresh clone, we can try to inspect or just be permissive.
    
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

  # =============================================
  # Erxes Services Routing
  # Note: These service names (ui, api, etc.) MUST match
  # the names in the cloned docker-compose.yml.
  # We include common variations to be safe.
  # =============================================

  # Frontend / UI
  ui:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.ui.rule=Host(\`${DOMAIN}\`)"
        - "traefik.http.routers.ui.entrypoints=web"
        - "traefik.http.services.ui.loadbalancer.server.port=3000"
  
  # API
  api:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.api.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/gateway\`)"
        - "traefik.http.routers.api.entrypoints=web"
        - "traefik.http.services.api.loadbalancer.server.port=3300"

  # Widgets
  widgets:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.widgets.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/widgets\`)"
        - "traefik.http.routers.widgets.entrypoints=web"
        - "traefik.http.services.widgets.loadbalancer.server.port=3200"
  
  # Integrations
  integrations-api:
    networks:
      - erxes
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.integrations.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/integrations\`)"
        - "traefik.http.routers.integrations.entrypoints=web"
        - "traefik.http.services.integrations.loadbalancer.server.port=3400"

networks:
  erxes:
    external: true
EOF
    
    print_step "Override file created." "✅"
}

# ==========================================
# 5. Launch
# ==========================================
step_launch() {
    print_step "Step 5: Launching Stack" "🚀"
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    cd "$ERXES_DIR" || exit 1

    # In Git Clone method, we rely on standard Docker Compose commands 
    # rather than 'npm run erxes up' which might be tailored to the create-app structure.
    # However, erxes usually includes a Makefile or package.json scripts.
    
    if [ -f "package.json" ]; then
         print_step "Running via npm install & start..." "📦"
         npm install
         # Trying standard start command or deploying dbs first
         # Usually: npm run erxes deploy-dbs -> npm run erxes up
         
         # Note: If the cloned repo doesn't map 'erxes' binary in package.json, this fails.
         # Fallback to direct docker compose
         if npm run | grep -q "erxes"; then
             npm run erxes deploy-dbs -- --prefix "$ERXES_DIR" --detach=false || true
             npm run erxes up -- --uis
         else
             print_step "NPM script 'erxes' not found. Falling back to Docker Compose..." "⚠️"
             docker compose up -d
         fi
    else
         print_step "No package.json. Running Docker Compose directly..." "🐳"
         docker compose up -d
    fi
}

# ==========================================
# RUN ALL
# ==========================================

step_install_deps
# step_create_user (Removed)
step_setup_app
step_init_swarm
# step_setup_mongo (Handled by repo's internal logic usually, or we assume docker-compose handles it)
step_setup_traefik_override
step_launch

print_step "Done! Visit http://$DOMAIN" "🎉"
print_step "Traefik Dashboard: http://$DOMAIN:8080" "🚥"
