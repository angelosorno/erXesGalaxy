#!/bin/bash

# Verificar si jq está instalado; si no, instalarlo
if ! command -v jq &> /dev/null; then
    echo -e "📦 Installing jq"
    sudo apt-get update
    sudo apt-get install -y jq
else
    echo -e "✅ jq is already installed"
fi

# Obtener el directorio del script actual
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Directorio del proyecto Erxes
ERXES_DIR="$SCRIPT_DIR/erxes"

# Ruta al archivo configs.json
CONFIGS_FILE="$ERXES_DIR/configs.json"

# Ajustar permisos y propiedad para garantizar que todos los archivos sean accesibles para el usuario actual desde el principio
echo -e "🔧 Setting ownership and permissions for $ERXES_DIR"
sudo chmod -R 775 "$ERXES_DIR"
sudo chown -R $USER:$USER "$ERXES_DIR"

# Generar mongo-key
echo -e "🔑 Generating mongo-key"
sudo bash -c "openssl rand -base64 756 > $ERXES_DIR/mongo-key"

# Cambiar permisos y propietario de mongo-key
echo -e "🔒 Setting permissions for mongo-key"
sudo chmod 400 "$ERXES_DIR/mongo-key"
sudo chown $USER:$USER "$ERXES_DIR/mongo-key"

# Generar key.pem y certificate.pem
echo -e "📜 Generating key.pem and certificate.pem"
sudo openssl req -newkey rsa:2048 -nodes -keyout "$ERXES_DIR/key.pem" -x509 -days 365 -out "$ERXES_DIR/certificate.pem" --batch

# Combinar key.pem y certificate.pem en mongo.pem
echo -e "📝 Combining key.pem and certificate.pem into mongo.pem"
sudo bash -c "cat $ERXES_DIR/key.pem $ERXES_DIR/certificate.pem > $ERXES_DIR/mongo.pem"
sudo chown $USER:$USER "$ERXES_DIR/mongo.pem"

# Ajustar permisos y propiedad para garantizar que todos los archivos sean accesibles para el usuario actual
echo -e "🔧 Setting ownership and permissions for $ERXES_DIR"
sudo chown -R $USER:$USER "$ERXES_DIR"
sudo chmod -R 755 "$ERXES_DIR"
sudo chmod 600 "$ERXES_DIR/mongo-key"
sudo chmod 600 "$ERXES_DIR/certificate.pem"
sudo chmod 600 "$ERXES_DIR/mongo.pem"

echo -e "🎉 MongoDB keys setup completed!"

# Configurar Elasticsearch en erxes
echo -e "⚙️ Configuring Elasticsearch for erxes"

# Asegúrate de que "essyncer" y "elasticsearch" estén agregados en configs.json
if ! jq -e '.essyncer' "$CONFIGS_FILE" > /dev/null; then
  echo -e "📝 Adding 'essyncer' config to configs.json"
  jq '. + {"essyncer": {}}' "$CONFIGS_FILE" > "$ERXES_DIR/tmp.json" && mv "$ERXES_DIR/tmp.json" "$CONFIGS_FILE"
else
  echo -e "✅ 'essyncer' is already present in configs.json"
fi

if ! jq -e '.elasticsearch' "$CONFIGS_FILE" > /dev/null; then
  echo -e "📝 Adding 'elasticsearch' config to configs.json"
  jq '. + {"elasticsearch": {}}' "$CONFIGS_FILE" > "$ERXES_DIR/tmp.json" && mv "$ERXES_DIR/tmp.json" "$CONFIGS_FILE"
else
  echo -e "✅ 'elasticsearch' is already present in configs.json"
fi

# Cambiar al directorio del proyecto
echo -e "📂 Changing directory to $ERXES_DIR"
cd "$ERXES_DIR" || { echo "❌ Failed to change directory"; exit 1; }

# Verificar que package.json exista
if [ ! -f "$ERXES_DIR/package.json" ]; then
    echo "❌ package.json not found in $ERXES_DIR"
    exit 1
fi

# Desplegar bases de datos
echo -e "🚀 Deploying databases"
sudo -u $USER npm run erxes deploy-dbs --prefix "$ERXES_DIR" --detach=false

sleep 60 # Pausa de 60 segundos para permitir la inspección manual de contenedores

if [ $? -ne 0 ]; then
    echo -e "❌ npm run erxes deploy-dbs failed"
    exit 1
fi


# Verificar servicios de base de datos
echo -e "🔍 Checking database services status"
MAX_ATTEMPTS=5
ATTEMPT=1

while ! docker ps -a | grep -q 'mongo.* Up '; do
    if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
        echo -e "❌ MongoDB failed to start after $MAX_ATTEMPTS attempts"
        echo -e "🔍 Checking MongoDB logs"
        MONGO_CONTAINER=$(docker ps -a --filter "name=mongo" --format "{{.Names}}")
        if [ -n "$MONGO_CONTAINER" ];then
            docker logs "$MONGO_CONTAINER"
        else
            echo "❌ No MongoDB container found"
        fi
        exit 1
    fi

    echo -e "⏳ Waiting for MongoDB to be up (Attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    sleep 10
    ((ATTEMPT++))
done

echo -e "🎉 Database services are up and running!"

# Obtener el nombre del contenedor MongoDB
echo -e "🔍 Finding MongoDB container name"
MONGO_CONTAINER=$(docker ps --filter "name=mongo" --format "{{.Names}}")

if [ -z "$MONGO_CONTAINER" ];then
    echo -e "❌ MongoDB container not found"
    exit 1
else
    echo -e "✅ MongoDB container found: $MONGO_CONTAINER\n"
fi

# Leer la contraseña de MongoDB desde configs.json
echo -e "🔐 Reading MongoDB password from configs.json"
MONGO_PASSWORD=$(jq -r '.mongo.password' "$CONFIGS_FILE")

if [ -z "$MONGO_PASSWORD" ];then
    echo "❌ MongoDB password not found in configs.json"
    exit 1
else
    echo -e "✅ MongoDB password found\n"
fi

# Entrar al contenedor MongoDB y configurar el conjunto de réplicas
echo -e "🚀 Setting up MongoDB replica set"
docker exec -it "$MONGO_CONTAINER" bash -c "mongo -u $USER -p $MONGO_PASSWORD --eval 'rs.initiate()'"

echo -e "🎉 MongoDB replica set setup completed!"
