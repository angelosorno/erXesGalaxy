#!/bin/bash
docker swarm leave --force

# Verificar si Docker Swarm ya está inicializado
SWARM_STATUS=$(sudo docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATUS" == "inactive" ]; then
    echo -e "🚀 Initializing Docker Swarm"
    if sudo docker swarm init; then
        echo -e "✅ Docker Swarm initialized successfully\n"
    else
        echo -e "❌ Failed to initialize Docker Swarm\n"
        exit 1
    fi
else    
    echo -e "🐳 Docker Swarm is already initialized"
fi

# Verificar si la red Docker overlay 'erxes' ya existe
NETWORK_EXISTS=$(docker network ls --filter name=erxes --format "{{.Name}}")

if [ "$NETWORK_EXISTS" == "erxes" ]; then
    echo -e "🌐 Docker overlay network 'erxes' already exists, no need to create it again."
else
    # Crear una red Docker overlay
    echo -e "🌐 Creating Docker overlay network 'erxes'"
    if docker network create --driver=overlay --attachable erxes; then
        echo -e "✅ Docker overlay network 'erxes' created successfully\n"
    else
        echo -e "❌ Failed to create Docker overlay network because alright exists \n"
        exit 1
    fi
fi

echo -e "🎉 Docker Swarm setup completed!"
