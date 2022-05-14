#!/bin/bash

#Inicialización de distribución de Linux basado en Ubuntu.  
apt-get update


#---------------------------------------------------Pregunta 1 : Implementación de Cluster VagrantVM2-----------------------------------------------------------


echo "Pregunta 1: Implementacion de Cluster"


# Implementación de LXD con la instalación de paquete snap. 
sudo snap install lxd

# Actualización de LXD en 20.04.
sudo snap refresh lxd

# Implementación de vagrant al grupo LXD.
sudo gpasswd -a vagrant lxd


# Remoción de archivo lxdconfig.yaml, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM2 más de una vez.  
sudo rm lxdconfig.yaml

# Se crea variable "clustercertificado" para almacenar el contenido del certificado del cluster a fin de agregar la misma a la configuración para la unión del nodo.  
clustercertificado=$(</vagrant/clustercer.crt)

# Creación de archivo lxcconfig extensión yaml, con la configuración seleccionada para la unión del nodo al Cluster, en la máquina virtual VagrantVM2.
cat >> lxdconfig.yaml << EOF
config: {}
networks: []
storage_pools: []
profiles: []
cluster:
  server_name: VagrantVM2
  enabled: true
  member_config:
  - entity: storage-pool
    name: local
    key: source
    value: ""
    description: '"source" property for storage pool "local"'
  cluster_address: 192.168.100.2:8443
  cluster_certificate: |
$clustercertificado
  server_address: 192.168.100.3:8443
  cluster_password: admin
  cluster_certificate_path: ""
  cluster_token: ""

EOF


echo "Inicializacion de Cluster usando Archivo Preseed"


# Ejecución de nodo para la union del mismo al cluster.
cat lxdconfig.yaml |sudo lxd init --preseed

# Impresión de la lista de los Clusters creados.
lxc cluster list


#------------------------------------------------ Pregunta 2 : Aprovisionamiento de Contenedores - Web1 -------------------------------------------------------


echo "Pregunta 2: Aprovisionamiento de Web1"


# Lanzamiento de contenedor "web1" usando la imagen de Ubuntu 20.04 en la Máquina Virtual VagrantVM2. 
# Se agrega el comando < /dev/null para que durante el lanzamiento del contenedor no lo reconozca como un YAML.  
lxc launch ubuntu:20.04 web1 --target VagrantVM2 < /dev/null


# Actualización de sistema operativo, Instalación de apache2, y habilitación del mismo en el contenedor.
lxc exec web1 -- apt update && apt upgrade -y
lxc exec web1 -- apt install apache2 -y
lxc exec web1 -- systemctl enable apache2
lxc list


echo "Configuración de Página"


# Remoción de archivo index.html, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM2 más de una vez.
sudo rm index.html

# Creación de archivo index.html.
touch index.html

# Configuración de archivo index.html.
cat >> index.html << EOF
<!DOCTYPE html>
<html>
<body>
<h1>Bienvenido al Servidor Web1</h1>
<p>Microproyecto 1 - Computacion en la Nube</p>
</body>
</html>
EOF

# Se envia el archivo index.html creado en la maquina virtual VagrantVM2 al contenedor en el directorio /var/www/html/
lxc file push index.html web1/var/www/html/index.html

# Se inicializa apache2
lxc exec web1 -- systemctl start apache2

# Se configura el forwarding de puertos.
lxc config device add web1 http proxy listen=tcp:0.0.0.0:5080 connect=tcp:127.0.0.1:80


#---------------------------------------------- Pregunta 2 : Aprovisionamiento de Contenedores - Web1backup -----------------------------------------------------


echo "Pregunta 2: Aprovisionamiento de Web1 - backup"


# Lanzamiento de contenedor "web1backup" usando la imagen de Ubuntu 20.04 en la Máquina Virtual VagrantVM2. 
# Se agrega el comando < /dev/null para que durante el lanzamiento del contenedor no lo reconozca como un YAML.  
lxc launch ubuntu:20.04 web1backup --target VagrantVM2 < /dev/null


# Actualización de sistema operativo, Instalación de apache2, y habilitación del mismo en el contenedor.
lxc exec web1backup -- apt update && apt upgrade -y
lxc exec web1backup -- apt install apache2 -y
lxc exec web1backup -- systemctl enable apache2
lxc list



echo "Configuración de Página"


# Remoción de archivo index.htaml, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM2 más de una vez.
sudo rm index.html

# Creación de archivo index.html.
touch index.html

# Configuración de archivo index.html.
cat >> index.html << EOF
<!DOCTYPE html>
<html>
<body>
<h1>Bienvenido al Servidor Web1-Backup</h1>
<p>Microproyecto 1 - Computacion en la Nube</p>
</body>
</html>
EOF

# Se envia el archivo index.html creado en la maquina virtual VagrantVM2 al contenedor en el directorio /var/www/html/
lxc file push index.html web1backup/var/www/html/index.html


# Se inicializa apache2
lxc exec web1backup -- systemctl start apache2

# Se configura el forwarding de puertos.
lxc config device add web1backup http proxy listen=tcp:0.0.0.0:3080 connect=tcp:127.0.0.1:80


#-----------------------------------------------------------Autor Daniela Restrepo Galván-----------------------------------------------------------------

