
# Instalación de Erxes en AlmaLinux (CentOS) 🚀

Este manual te guiará a través del proceso de instalación de Erxes en una máquina con AlmaLinux (CentOS). Utilizaremos varios scripts para automatizar la configuración e instalación de los componentes necesarios.

## Pasos de instalación 🛠️

### 1. Preparar los scripts 📂

Asegúrate de que tienes los siguientes archivos de script en el mismo directorio:

- `1.install.sh`
- `2.userCreate.sh`
- `3.erxesApp.sh`
- `4.dockerSwarn.sh`
- `5.upDBmongo.sh`

### 2. Crear el archivo .env 📄

Crea un archivo `.env` en el mismo directorio con el siguiente contenido:

```
USER_PASSWORD=YOUR_PASSWORD
```

Actualizalo con la contraseña que desees asignar al usuario `erxes`



Reemplaza `sub.domain.org` con el dominio que usara en el App erXes

```
DOMAIN=YOUR_DOMAIN
```

### 3. Configurar permisos de ejecución 🔑

Otorga permisos de ejecución a todos los scripts:

```bash
sudo chmod +x Start.sh 1.install.sh 2.userCreate.sh 3.erxesApp.sh 4.dockerSwarn.sh 5.upDBmongo.sh 6.setupNginx.sh
```

### 4. Ejecutar el script principal ▶️

Ejecuta el script `Start.sh` para iniciar el proceso de instalación:

```bash
./Start.sh
```

## Credenciales de usuario 🔐

- Usuario: `erxes`
- Clave: La que hayas definido en el archivo `.env`

