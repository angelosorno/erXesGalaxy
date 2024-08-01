#!/bin/bash

# Cargar variables del archivo .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ El archivo .env no existe. Por favor, crea uno con la variable DOMAIN."
  exit 1
fi

# Verificar que la variable DOMAIN esté definida
if [ -z "$DOMAIN" ]; then
  echo "❌ La variable DOMAIN no está definida en el archivo .env."
  exit 1
fi

# Obtener el directorio del script actual
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Directorio del proyecto Erxes
ERXES_DIR="$SCRIPT_DIR/erxes"

# Limpiar el directorio del proyecto si ya existe
if [ -d "$ERXES_DIR" ]; then
  echo -e "🧹 Cleaning up existing directory $ERXES_DIR"
  sudo rm -rf "$ERXES_DIR"
fi

# Crear el proyecto erxes
echo -e "🚀 Creating Erxes project"
sudo -u $USER DOMAIN=$DOMAIN create-erxes-app erxes

# Ajustar permisos y propiedad para garantizar que todos los archivos sean accesibles para el usuario actual
echo -e "🔧 Setting ownership and permissions for $ERXES_DIR"
sudo chown -R $USER:$USER "$ERXES_DIR"
sudo chmod -R 755 "$ERXES_DIR"

# Cambiar al directorio del proyecto
echo -e "📂 Changing directory to $ERXES_DIR"
cd "$ERXES_DIR" || { echo "❌ Failed to change directory"; exit 1; }

# Obtener la última versión etiquetada como "latest" de erxes desde npm
LATEST_VERSION=$(npm view erxes dist-tags.latest)
if [ -z "$LATEST_VERSION" ]; then
  echo "❌ Failed to retrieve the latest version of erxes from npm"
  exit 1
fi

# Actualizar el archivo package.json con la última versión etiquetada como "latest" de erxes
echo -e "✏️ Updating package.json with the latest erxes version ($LATEST_VERSION)"
sudo -u $USER jq --arg version "$LATEST_VERSION" '.dependencies.erxes = $version' package.json > tmp.json && mv tmp.json package.json

# Limpiar node_modules y package-lock.json si existen
echo -e "🧹 Cleaning up node_modules and package-lock.json"
sudo -u $USER rm -rf node_modules package-lock.json

# Instalar dependencias npm
echo -e "📦 Installing npm dependencies"
echo -e "⌛ This might take a few minutes, please wait..."
sudo -u $USER npm install --loglevel=info

if [ $? -eq 0 ]; then
    echo -e "✅ npm dependencies installed successfully"
else
    echo -e "❌ npm install failed"
    exit 1
fi

# Agregar configuraciones a configs.json
echo -e "⚙️ Adding configurations to configs.json"
sudo -u $USER jq '. + {"essyncer": {}, "elasticsearch": {}}' configs.json > tmp.json && mv tmp.json configs.json

echo -e "🎉 Setup completed successfully!"
