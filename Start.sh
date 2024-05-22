#!/bin/bash

# Ejecutar 1.install.sh
echo -e "🚀 Step 1: Ejecutar 1.install.sh"
read -p "¿Desea continuar? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    ./1.install.sh
    echo -e "✅ 1.install.sh completado\n"
else
    echo -e "⏩ Saltando 1.install.sh\n"
fi

# Ejecutar 2.userCreate.sh
echo -e "🚀 Step 2: Ejecutar 2.userCreate.sh"
read -p "¿Desea continuar? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    ./2.userCreate.sh
    echo -e "✅ 2.userCreate.sh completado\n"
else
    echo -e "⏩ Saltando 2.userCreate.sh\n"
fi

# Ejecutar 3.erxes-app.sh
echo -e "🚀 Step 3: Ejecutar 3.erxes-app.sh"
read -p "¿Desea continuar? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    ./3.erxesApp.sh
    echo -e "✅ 3.erxes-app.sh completado\n"
else
    echo -e "⏩ Saltando 3.erxes-app.sh\n"
fi

# Ejecutar 4.dockerSwarn.sh
echo -e "🚀 Step 4: Ejecutar 4.dockerSwarn.sh"
read -p "¿Desea continuar? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    ./4.dockerSwarn.sh
    echo -e "✅ 4.dockerSwarn.sh completado\n"
else
    echo -e "⏩ Saltando 4.dockerSwarn.sh\n"
fi

# Ejecutar 5.upDBmongo.sh
echo -e "🚀 Step 5: Ejecutar 5.upDBmongo.sh"
read -p "¿Desea continuar? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    ./5.upDBmongo.sh
    echo -e "✅ 5.upDBmongo.sh completado\n"
else
    echo -e "⏩ Saltando 5.upDBmongo.sh\n"
fi

echo -e "🎉 Todo completado!"