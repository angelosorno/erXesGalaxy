#!/bin/bash

# Registrar la hora actual
now=$(date +'%H:%M:%S')

# Paso 1: Actualizar el sistema
echo -e "🚀 Step 1 $now : Updating system"
sudo yum update -y
sudo yum install epel-release -y

# Paso 2: Instalar nginx
now=$(date +'%H:%M:%S')
echo -e "🌐 Step 2 $now : Installing nginx"
sudo yum install nginx -y
sudo systemctl start nginx
sudo yum check-update

# Paso 3: Instalar Docker
now=$(date +'%H:%M:%S')
echo -e "🐳 Step 3 $now : Installing Docker"
curl -fsSL https://get.docker.com/ | sh
sudo systemctl start docker
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# Paso 4: Instalar docker-compose
now=$(date +'%H:%M:%S')
echo -e "🔧 Step 4 $now : Installing docker-compose"
sudo yum install docker-ce -y
sudo yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/p/pigz-2.3.4-1.el7.x86_64.rpm -y
sudo yum install http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm -y
sudo yum list docker-ce --showduplicates | sort -r docker-ce.x86_64  17.09.ce-1.el7.centos  docker-ce-stable
sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Paso 5: Instalar Node.js
now=$(date +'%H:%M:%S')
echo -e "🟢 Step 5 $now : Installing Node.js"
curl -sL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install nodejs -y
node --version

# Paso 6: Instalar npm
now=$(date +'%H:%M:%S')
echo -e "📦 Step 6 $now : Installing npm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
. ~/.nvm/nvm.sh
nvm --version
nvm install node
nvm install --lts
nvm install 9.6.7

# Paso 7: Instalar AWS CLI
now=$(date +'%H:%M:%S')
echo -e "☁️ Step 7 $now : Installing AWS CLI"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Paso 8: Instalar create-erxes-app
now=$(date +'%H:%M:%S')
echo -e "✨ Step 8 $now : Installing create-erxes-app"
sudo npm install -g create-erxes-app -y

# Paso 9: Instalar jq
now=$(date +'%H:%M:%S')
echo -e "🔧 Step 9 $now : Installing jq"
sudo yum install -y jq

echo -e "🎉 All steps completed successfully!"