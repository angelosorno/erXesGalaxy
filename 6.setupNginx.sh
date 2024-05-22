#!/bin/bash

# Cargar las variables del archivo .env
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo "❌ El archivo .env no se encontró. Asegúrate de que exista en el directorio actual."
  exit 1
fi

# Verificar que la variable DOMAIN esté establecida
if [ -z "$DOMAIN" ]; then
  echo "❌ La variable DOMAIN no está establecida en el archivo .env."
  exit 1
fi

# Crear el directorio locales en /home/erxes/erxes
echo -e "📁 Creating locales directory in /home/erxes/erxes"
mkdir -p /home/erxes/erxes/locales

# Cambiar al directorio de trabajo
cd /home/erxes/erxes || { echo "Failed to change directory to /home/erxes/erxes"; exit 1; }

# Actualizar la versión de erxes en configs.json a la última versión
echo -e "🔄 Updating erxes version in configs.json"
LATEST_VERSION=$(npm view erxes version)
jq --arg version "$LATEST_VERSION" '.version = $version' configs.json > tmp.json && mv tmp.json configs.json

# Iniciar los servicios de la aplicación (erxes core, uis y gateway)
echo -e "🚀 Starting application services (erxes core, uis, and gateway)"
npm run erxes up -- --uis

# Esperar hasta que los contenedores estén listos
echo -e "⌛ Waiting for all services to be up"
while ! docker ps -a | grep -q 'gateway.* Up .* (healthy)'; do
    sleep 5
    echo -e "⏳ Waiting for gateway container to become healthy..."
done

echo -e "🎉 All application services are up and running!"

# Copiar el archivo de configuración de nginx desde erxes.conf a /etc/nginx/sites-enabled/erxes.conf
echo -e "📝 Copying nginx configuration file to /etc/nginx/sites-enabled/erxes.conf"
sudo cp erxes.conf /etc/nginx/sites-enabled/erxes.conf

# Reemplazar el placeholder del dominio en el archivo de configuración de nginx
echo -e "🔧 Updating nginx configuration with the domain from .env"
sudo sed -i "s/example.com/$DOMAIN/g" /etc/nginx/sites-enabled/erxes.conf

# Recargar nginx para aplicar la nueva configuración
echo -e "🔄 Reloading nginx"
sudo systemctl reload nginx

echo -e "🎉 Nginx configuration completed!"
