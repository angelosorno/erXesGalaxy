#!/bin/bash

# Crear el proyecto erxes
echo -e "🚀 Creating Erxes project"
create-erxes-app erxes

# Cambiar al directorio del proyecto
echo -e "📂 Changing directory to /home/erxes/erxes"
cd /home/erxes/erxes || { echo "Failed to change directory"; exit 1; }

# Instalar dependencias npm
echo -e "📦 Installing npm dependencies"
npm install || { echo "npm install failed"; exit 1; }

echo -e "🎉 Setup completed successfully!"