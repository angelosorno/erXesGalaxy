#!/bin/bash

# Función para registrar la hora actual
log_time() {
    echo $(date +'%H:%M:%S')
}

# Función para imprimir mensajes con formato
print_step() {
    echo -e "$2 Step $(log_time) : $1"
}

# Paso 1: Actualizar el sistema
print_step "Updating system" "🚀"
sudo apt-get update -y

# Paso 2: Instalar nginx
print_step "Installing nginx" "🌐"
sudo apt install nginx -y
sudo apt update -y

# Paso 3: Instalar Docker si no está instalado
if ! [ -x "$(command -v docker)" ]; then
    print_step "Installing Docker" "🐳"
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    apt-cache policy docker-ce
    sudo apt install docker-ce -y
else
    print_step "Docker is already installed" "🐳"
fi

# Paso 4: Instalar docker-compose si no está instalado
if ! [ -x "$(command -v docker-compose)" ]; then
    print_step "Installing docker-compose" "🔧"
    sudo apt-get update -y
    sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    print_step "docker-compose is already installed" "🔧"
fi

# Paso 5: Instalar Node.js
if ! [ -x "$(command -v node)" ]; then
    print_step "Installing Node.js" "🟢"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    curl -s https://deb.nodesource.com/setup_18.x | sudo bash
    sudo apt-get install nodejs -y
else
    print_step "Node.js is already installed" "🟢"
fi

# Paso 6: Instalar npm
if ! [ -x "$(command -v npm)" ]; then
    print_step "Installing npm" "📦"
    sudo apt install npm -y
else
    print_step "npm is already installed" "📦"
fi

# Paso 7: Instalar AWS CLI
if ! [ -x "$(command -v aws)" ]; then
    print_step "Installing AWS CLI" "☁️"
    sudo apt-get install awscli -y
else
    print_step "AWS CLI is already installed" "☁️"
fi

# Paso 8: Instalar create-erxes-app
if ! [ -x "$(command -v create-erxes-app)" ]; then
    print_step "Installing create-erxes-app" "✨"
    sudo npm install -g create-erxes-app -y
else
    print_step "create-erxes-app is already installed" "✨"
fi

print_step "All steps completed successfully!" "🎉"
