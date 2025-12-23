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

if [ -z "$DOMAIN" ] || [ -z "$USER_PASSWORD" ]; then
  echo "❌ Missing DOMAIN or USER_PASSWORD in .env"
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

    # Install Nginx
    if check_cmd nginx; then
        print_step "Nginx already installed" "✅"
    else
        print_step "Installing Nginx..." "🌐"
        if [ "$OS_TYPE" == "Linux" ]; then
            sudo apt-get install nginx -y
        else
            brew install nginx
        fi
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
         print_step "Installing Node.js (via nvm if possible, else system)..." "🟢"
         # Simplified for this script
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
# 2. User Creation (Linux Only)
# ==========================================
step_create_user() {
    print_step "Step 2: User Configuration" "👤"
    
    if [ "$OS_TYPE" == "Mac" ]; then
        print_step "Skipping user creation on Mac (running as current user)" "⏩"
        RUN_USER="$USER"
        return
    fi

    RUN_USER="erxes"
    if id "$RUN_USER" &>/dev/null; then
        print_step "User '$RUN_USER' already exists" "✅"
    else
        print_step "Creating user '$RUN_USER'..." "👤"
        sudo useradd -m $RUN_USER
        echo "${RUN_USER}:${USER_PASSWORD}" | sudo chpasswd
        sudo usermod -aG sudo $RUN_USER
        sudo usermod -aG docker $RUN_USER
    fi
}

# ==========================================
# 3. App Setup
# ==========================================
step_setup_app() {
    print_step "Step 3: App Setup" "🚀"
    
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    
    # Needs to be handled carefully with permissions if switching users
    # For simplicity in this unified script, we'll do operations as current user
    # and fix ownership at the end if on Linux.

    if [ -d "$ERXES_DIR" ]; then 
        print_step "Cleaning old directory..." "🧹"
        sudo rm -rf "$ERXES_DIR"
    fi

    print_step "Creating erxes app..." "✨"
    # Execute create-erxes-app
    # On linux potentially as the specific user, but here we run as invoker
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
# 4. Swarm Init
# ==========================================
step_init_swarm() {
    print_step "Step 4: Docker Swarm" "🐝"
    
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
# 5. Database Setup
# ==========================================
step_setup_mongo() {
    print_step "Step 5: Database Setup" "🗄️"
    # Ensure variables from App Step are valid or re-set
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
    sleep 5 # Extra buffer

    MONGO_CONTAINER=$(docker ps --filter "name=mongo" --format "{{.Names}}" | head -n 1)
    MONGO_PASSWORD=$(jq -r '.mongo.password' configs.json)
    
    if [ -n "$MONGO_CONTAINER" ] && [ -n "$MONGO_PASSWORD" ]; then
         print_step "Initializing Replica Set..." "⚙️"
         # Exec into container
         docker exec "$MONGO_CONTAINER" mongo -u erxes -p "$MONGO_PASSWORD" --eval 'rs.initiate()' || true
    fi
}

# ==========================================
# 6. Final Launch & Nginx
# ==========================================
step_setup_nginx() {
    print_step "Step 6: Launch & Nginx" "🚀"
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    ERXES_DIR="$SCRIPT_DIR/erxes"
    cd "$ERXES_DIR" || exit 1

    mkdir -p locales
    
    LATEST_VERSION=$(npm view erxes version)
    jq --arg version "$LATEST_VERSION" '.version = $version' configs.json > tmp.json && mv tmp.json configs.json

    print_step "Starting App Services..." "▶️"
    npm run erxes up -- --uis

    # Nginx Config
    print_step "Configuring Nginx..." "🔧"
    NGINX_CONF_SRC="$SCRIPT_DIR/erxes.conf"
    
    if [ "$OS_TYPE" == "Linux" ]; then
        sudo cp "$NGINX_CONF_SRC" /etc/nginx/sites-enabled/erxes.conf
        sudo sed -i "s/example.com/$DOMAIN/g" /etc/nginx/sites-enabled/erxes.conf
        sudo systemctl reload nginx
    elif [ "$OS_TYPE" == "Mac" ]; then
        # Homebrew Nginx usually at /opt/homebrew/etc/nginx/servers/
        NGINX_SERVERS_DIR="$(brew --prefix)/etc/nginx/servers"
        if [ -d "$NGINX_SERVERS_DIR" ]; then
             cp "$NGINX_CONF_SRC" "$NGINX_SERVERS_DIR/erxes.conf"
             sed -i '' "s/example.com/$DOMAIN/g" "$NGINX_SERVERS_DIR/erxes.conf"
             brew services reload nginx
        else
             print_step "⚠️  Could not find Nginx servers directory. Configure manually." "⚠️"
        fi
    fi
}

# ==========================================
# RUN ALL
# ==========================================

step_install_deps
step_create_user
step_setup_app
step_init_swarm
step_setup_mongo
step_setup_nginx

print_step "Done! Visit http://$DOMAIN" "🎉"
