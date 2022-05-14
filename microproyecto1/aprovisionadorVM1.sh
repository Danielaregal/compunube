#!/bin/bash

#Inicialización de distribución de Linux basado en Ubuntu.  
apt-get update


#---------------------------------------------------Pregunta 1 : Implementación de Cluster VagrantVM1-----------------------------------------------------------


echo "Pregunta 1: Implementacion de Cluster"



# Implementación de LXD con la instalación de paquete snap. 
sudo snap install lxd

# Actualización de LXD en 20.04.
sudo snap refresh lxd

# Implementación de vagrant al grupo LXD.
sudo gpasswd -a vagrant lxd


# Remoción de archivo lxdconfig.yaml, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM1 más de una vez.  
sudo rm lxdconfig.yaml

# Creación de archivo lxcconfig extensión yaml, con la configuración seleccionada para el nodo de arranque del Cluster, en la máquina virtual VagrantVM1.
cat >> lxdconfig.yaml << EOF
config:
  core.https_address: 192.168.100.2:8443
  core.trust_password: admin
networks:
- config:
    bridge.mode: fan
    fan.underlay_subnet: auto
  description: ""
  name: lxdfan0
  type: ""
storage_pools:
- config: {}
  description: ""
  name: local
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: lxdfan0
      type: nic
    root:
      path: /
      pool: local
      type: disk
  name: default
cluster:
  server_name: VagrantVM1
  enabled: true
  member_config: []
  cluster_address: ""
  cluster_certificate: ""
  server_address: ""
  cluster_password: ""
  cluster_certificate_path: ""
  cluster_token: ""
EOF


echo "Inicializacion de Cluster usando Archivo Preseed"


# Ejecución de nodo de arranque.
cat lxdconfig.yaml | lxd init --preseed

# Impresión de la lista de los Clusters creados.
lxc cluster list

echo "Creación de Certificado de Cluster"
# Se incluye la dirección y el certificado del nodo de arranque de destino, a fin de crear una entrada compatible con YAML.
sudo cp /var/snap/lxd/common/lxd/cluster.crt /vagrant/cluster.crt

# Se modifca la indentacion inicial de todas las lineas del certificado agregando 4 espacios, mediante el comando sed 
# y se almacena en un archivo nuevo "clustercer.crt". 
sed 's/^/    /g' /vagrant/cluster.crt > /vagrant/clustercer.crt


#-------------------------------------------------Pregunta 2 : Aprovisionamiento de Contenedores - HaProxy -----------------------------------------------------


echo "Pregunta 2: Aprovisionamiento de HaProxy"


# Lanzamiento de contenedor "haproxy" usando la imagen de Ubuntu 20.04 en la Máquina Virtual VagrantVM1. 
# Se agrega el comando < /dev/null para que durante el lanzamiento del contenedor no lo reconozca como un YAML.  
lxc launch ubuntu:20.04 haproxy --target VagrantVM1 < /dev/null

# Actualización de sistema operativo, Instalación de HaProxy, y habilitación del mismo en el contenedor.
lxc exec haproxy -- apt update && apt upgrade -y 
lxc exec haproxy -- apt install haproxy -y
lxc exec haproxy -- systemctl enable haproxy


echo "Configuración HaProxy"
 
# Remoción de archivo haproxy.cfg, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM1 más de una vez.
sudo rm haproxy.cfg

# Creación de archivo haproxy.cfg
touch haproxy.cfg

# Configuración de archivo haproxy.cfg, para el funcionamiento del HaProxy y el balanceo de cargas.
cat >> haproxy.cfg << EOF
global
  log /dev/log  local0
  log /dev/log  local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
  user haproxy
  group haproxy
  daemon

  # Default SSL material locations
  ca-base /etc/ssl/certs
  crt-base /etc/ssl/private

  # Default ciphers to use on SSL-enabled listening sockets.
  # For more information, see ciphers(1SSL). This list is from:
  #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  # An alternative list with additional directives can be obtained from
  #  https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=haproxy
  ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
  ssl-default-bind-options no-sslv3

defaults
  log global
  mode  http
  option  httplog
  option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
  errorfile 400 /etc/haproxy/errors/400.http
  errorfile 403 /etc/haproxy/errors/403.http
  errorfile 408 /etc/haproxy/errors/408.http
  errorfile 500 /etc/haproxy/errors/500.http
  errorfile 502 /etc/haproxy/errors/502.http
  errorfile 503 /etc/haproxy/errors/503.http
  errorfile 504 /etc/haproxy/errors/504.http


backend web-backend
   balance roundrobin
   stats enable
   stats auth admin:admin
   stats uri /haproxy?stats

   server web1 192.168.100.3:5080 check
   server web2 192.168.100.4:5080 check
   server web1backup 192.168.100.3:3080 check backup
   server web2backup 192.168.100.4:3080 check backup
   

frontend http
  bind *:80
  default_backend web-backend

EOF

# Se envia el archivo haproxy.cfg creado en la maquina virtual VagrantVM1 al contenedor en el directorio /etc/haproxy/ 
lxc file push haproxy.cfg haproxy/etc/haproxy/haproxy.cfg

# Se inicializa HaProxy
lxc exec haproxy -- systemctl start haproxy

# Se configura el forwarding de puertos.
lxc config device add haproxy http proxy listen=tcp:0.0.0.0:1080 connect=tcp:127.0.0.1:80



#----------------------------------------------------------- Configuración Servidores No Disponibles -------------------------------------------------------


echo "Configuración para manejo de servidores no disponibles"


# Remoción de archivo 503.htmal, a fin de evitar sobreescribir el mismo cuando se aprovisiona la máquina virtual VagrantVM1 más de una vez.
sudo rm 503.html

# Creación de archivo 503.html
touch 503.html

# Configuración de archivo 503.html, para el manejo de servidores cuando los mismos no están disponibles. 
cat >> 503.html << EOF
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<html>
<body>
<h1> Ocurrio un problema tecnico </h1>
<p> Agradecemos su compresion, estamos trabajando para brindarle el mejor servicio </p>
</body>
</html>
EOF

# Se envia el archivo 503.html creado en la maquina virtual VagrantVM1 al contenedor en el directorio /etc/haproxy/errors 
lxc file push /home/vagrant/503.html haproxy/etc/haproxy/errors/503.http

#----------------------------------------------------------------------------------------------------------------------------------------------------------

# Se reinicia el servicio HaProxy
lxc exec haproxy -- systemctl restart haproxy



#-----------------------------------------------------------Autor Daniela Restrepo Galván-----------------------------------------------------------------




























