#!/bin/bash

# Inicializar Docker Swarm
echo -e "🚀 Initializing Docker Swarm"
if docker swarm init; then
    echo -e "✅ Docker Swarm initialized successfully\n"
else
    echo -e "❌ Failed to initialize Docker Swarm\n"
    exit 1
fi

# Crear una red Docker overlay
echo -e "🌐 Creating Docker overlay network 'erxes'"
if docker network create --driver=overlay --attachable erxes; then
    echo -e "✅ Docker overlay network 'erxes' created successfully\n"
else
    echo -e "❌ Failed to create Docker overlay network\n"
    exit 1
fi

echo -e "🎉 Docker Swarm setup completed!"