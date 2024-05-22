#!/bin/bash

# Generar mongo-key
echo -e "🔑 Generating mongo-key"
openssl rand -base64 756 > mongo-key

# Cambiar permisos y propietario de mongo-key
echo -e "🔒 Setting permissions for mongo-key"
sudo chmod 400 mongo-key
sudo chown 999:999 mongo-key

# Generar key.pem y certificate.pem
echo -e "📜 Generating key.pem and certificate.pem"
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem --batch

# Combinar key.pem y certificate.pem en mongo.pem
echo -e "📝 Combining key.pem and certificate.pem into mongo.pem"
cat key.pem certificate.pem > mongo.pem

echo -e "🎉 MongoDB keys setup completed!"

# Configurar Elasticsearch en erxes
echo -e "⚙️ Configuring Elasticsearch for erxes"

# Asegúrate de que "essyncer" y "elasticsearch" estén agregados en configs.json
echo -e "📝 Adding Elasticsearch config to configs.json"
jq '. + {"essyncer": {}, "elasticsearch": {}}' configs.json > tmp.json && mv tmp.json configs.json

# Desplegar bases de datos
echo -e "🚀 Deploying databases"
npm run erxes deploy-dbs

# Verificar servicios de base de datos
echo -e "🔍 Checking database services status"
while ! docker ps -a | grep -q 'mongo.* Up '; do
    echo -e "⏳ Waiting for MongoDB to be up..."
    sleep 5
done

echo -e "🎉 Database services are up and running!"

# Obtener el nombre del contenedor MongoDB
echo -e "🔍 Finding MongoDB container name"
MONGO_CONTAINER=$(docker ps --filter "name=mongo" --format "{{.Names}}")

if [ -z "$MONGO_CONTAINER" ]; then
    echo -e "❌ MongoDB container not found"
    exit 1
else
    echo -e "✅ MongoDB container found: $MONGO_CONTAINER\n"
fi

# Leer la contraseña de MongoDB desde configs.json
echo -e "🔐 Reading MongoDB password from configs.json"
MONGO_PASSWORD=$(jq -r '.mongo.password' configs.json)

if [ -z "$MONGO_PASSWORD" ]; then
    echo -e "❌ MongoDB password not found in configs.json"
    exit 1
else
    echo -e "✅ MongoDB password found\n"
fi

# Entrar al contenedor MongoDB y configurar el conjunto de réplicas
echo -e "🚀 Setting up MongoDB replica set"
docker exec -it "$MONGO_CONTAINER" bash -c "mongo -u erxes -p $MONGO_PASSWORD --eval 'rs.initiate()'"

# Salir del contenedor MongoDB
echo -e "🔚 Exiting MongoDB container"
docker exec -it "$MONGO_CONTAINER" bash -c "exit"

echo -e "🎉 MongoDB replica set setup completed!"
