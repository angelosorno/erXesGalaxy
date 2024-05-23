#!/bin/bash

# Cargar variables del archivo .env
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo "❌ El archivo .env no existe. Por favor, crea uno con la variable USER_PASSWORD."
  exit 1
fi


# Instalar los paquetes necesarios
sudo yum install -y passwd util-linux

# Crear un nuevo usuario llamado 'erxes' y asignar la contraseña desde el .env
sudo useradd -m erxes
echo "erxes:${USER_PASSWORD}" | sudo chpasswd

# Agregar el usuario 'erxes' al grupo 'wheel' para otorgarle privilegios de superusuario
sudo usermod -aG wheel erxes

# Agregar el usuario 'erxes' al grupo 'docker'
sudo usermod -aG docker erxes

# Cerrar sesión e iniciar sesión como 'erxes'
su - erxes

# Verificar que el usuario 'erxes' pueda ejecutar comandos de Docker sin 'sudo'
docker ps -a

# Informar al usuario que la creación y configuración del usuario ha sido exitosa
echo -e "✅ El usuario 'erxes' ha sido creado y configurado exitosamente."