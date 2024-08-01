#!/bin/bash

# Cargar variables del archivo .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ El archivo .env no existe. Por favor, crea uno con la variable USER_PASSWORD="
  exit 1
fi

# Verificar que la variable USER_PASSWORD esté definida
if [ -z "$USER_PASSWORD" ]; then
  echo "❌ La variable USER_PASSWORD no está definida en el archivo .env."
  exit 1
fi

# Función para registrar la hora actual
log_time() {
    echo $(date +'%H:%M:%S')
}

# Función para imprimir mensajes con formato
print_step() {
    echo -e "$2 Step $(log_time) : $1"
}

# Paso 1: Instalar los paquetes necesarios
print_step "Installing necessary packages" "🚀"
sudo apt-get install -y passwd util-linux

# Paso 2: Crear un nuevo usuario llamado 'erxes' y asignar la contraseña desde el .env
if id "erxes" &>/dev/null; then
    print_step "User 'erxes' already exists" "👤"
else
    print_step "Creating user 'erxes' and setting password" "👤"
    sudo useradd -m erxes
    echo "erxes:${USER_PASSWORD}" | sudo chpasswd
fi

# Paso 3: Agregar el usuario 'erxes' al grupo 'sudo' para otorgarle privilegios de superusuario
print_step "Adding user 'erxes' to sudo group" "🔑"
sudo usermod -aG sudo erxes

# Paso 4: Agregar el usuario 'erxes' al grupo 'docker'
print_step "Adding user 'erxes' to docker group" "🐳"
sudo usermod -aG docker erxes

# Paso 5: Verificar que el usuario 'erxes' pueda ejecutar comandos de Docker sin 'sudo'
print_step "Verifying Docker setup for 'erxes'" "🔧"
sudo -u erxes -H sh -c 'docker ps -a' &>/dev/null

if [ $? -eq 0 ]; then
    print_step "Docker setup for 'erxes' verified successfully" "✅"
else
    print_step "Failed to verify Docker setup for 'erxes'" "❌"
    exit 1
fi

# Paso 6: Informar al usuario que la creación y configuración del usuario ha sido exitosa
print_step "User 'erxes' has been created and configured successfully." "✅"
