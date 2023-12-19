#!/bin/bash

# Lista de colores para el terminal
RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'

# Carga de Variables Desde Archivo.
source ./full_config.conf

# Comprobacion de los datos de las variables.
echo -e "${RESTORE}"
echo -e "#########################################"
echo -e "# Compruebe si los datos son correctos: #"
echo -e "#########################################\n"
echo -e "${RESTORE}Directorio base:${GREEN} $BASE"
echo -e "${RESTORE}Directorio registry:${GREEN} $REGISTRY_BASE"
echo -e "${RESTORE}Interfaz OCP Network:${GREEN} $EthernetBoot"
echo -e "${RESTORE}IP Stargate:${GREEN} $IPHelper"
echo -e "${RESTORE}IP OCP Network:${GREEN} $IPSegment"
echo -e "${RESTORE}Direccion de email:${GREEN} $emailAddress"
echo -e "${RESTORE}Hostname:${GREEN} $HostName"
echo -e "${RESTORE}Nombre del cluster:${GREEN} $ClusterName"
echo -e "${RESTORE}Dominio:${GREEN} $Domain"
echo -e "${RESTORE}Usuario Registry:${GREEN} $HttpUser"
echo -e "${RESTORE}Contraseña Registry:${GREEN} $HttpPasswd"
echo -e "${RESTORE}Version de CoreOS:${GREEN} $CoreOSVer"
echo -e "${RESTORE}Subversion de CoreOS:${GREEN} $CoreOSSubVer"
echo -e "${RESTORE}Version de OCP:${GREEN} $OCP_RELEASE"
echo -e "${RESTORE}Version de helm:${GREEN} $HELM"
echo -e "${RESTORE}Pais:${GREEN} $PAIS"
echo -e "${RESTORE}Comunidad: ${GREEN} $COMUNIDAD"
echo -e "${RESTORE}Provincia: ${GREEN} $PROVINCIA"
echo -e "${RESTORE}Empresa: ${GREEN} $EMPRESA"
echo -e "${RESTORE}Departamento: ${GREEN} $DEPARTAMENTO"
echo -e "${RESTORE}Mac Bootstrap:${GREEN} $MAC_Bootstrap"
echo -e "${RESTORE}Mac Master 1:${GREEN} $MAC_Master_01"
echo -e "${RESTORE}Mac Master 2:${GREEN} $MAC_Master_02"
echo -e "${RESTORE}Mac Master 3:${GREEN} $MAC_Master_03"
echo -e "${RESTORE}Mac Worker 1:${GREEN} $MAC_Worker_01"
echo -e "${RESTORE}Mac Worker 2:${GREEN} $MAC_Worker_02"
echo -e "${RESTORE}Mac Worker 3:${GREEN} $MAC_Worker_03"
echo -e "${RESTORE}IP Servidor NTP 1:${GREEN} $NTPSERVER1"
echo -e "${RESTORE}IP Servidor NTP 2:${GREEN} $NTPSERVER2"
echo -e "${RESTORE}IP Servidor NTP 3:${GREEN} $NTPSERVER3"
echo -e "${RESTORE}IP Servidor NTP 4:${GREEN} $NTPSERVER4"
echo -e "${RESTORE}"

# Logica para permitir cortar la ejecucion en caso de que las variables sean incorrectas.
echo "¿Son correctas las variables? (Y/N)";read RESPUESTA
if [[ $RESPUESTA != [Yy] ]];
then
    exit;
fi

#-----------------------------------------------------------------------

###########################
#         BLOQUE          #
#           DE            #
#   FUNCIONES GENERALES   #
###########################

#-----------------------------------------------------------------------

configura_repos(){
  echo -e "\n#####################################"
  echo -e "# Configurando Repositorios Locales #"
  echo -e "#####################################\n"

  # Copia del archivo de configuracion de repositorios.
  cp ./Template_Files/dvd.repo /etc/yum.repos.d/dvd.repo
}

#-----------------------------------------------------------------------

instala_paquetes(){
  # Instalacion de paquetes con yum.
  echo -e "\n##################################"
  echo -e "# Instalando paquetes requeridos #"
  echo -e "##################################\n"
  
  pkgs="jq openssl podman httpd-tools curl wget chrony tree bind httpd tftp-server syslinux-tftpboot dhcp-server chrony haproxy"
  
  yum install $pkgs -y
}

#-----------------------------------------------------------------------

destarea_mirror(){
  echo -e "\n###################################"
  echo -e "# Destareando archivos necesarios #"
  echo -e "###################################\n"

  tar -xvf /*-registry.tar -C /
}

#-----------------------------------------------------------------------

actualiza_hostname(){
  echo -e "\n#########################"
  echo -e "# Actualizando Hostname #"
  echo -e "#########################\n"

  # Actualizacion de hostname y dominio en base al archivo de variables.
  hostname $HostName.$ClusterName.$Domain
  hostnamectl set-hostname $HostName.$ClusterName.$Domain

  HostName=`hostname`
  ShortHostName=`hostname -s`
  Domain=`hostname -d`

  # Muestreo del resultado.
  echo -e "${RESTORE}Hostname completo:${GREEN} `hostname`"
  echo -e "${RESTORE}Hostname corto:${GREEN} `hostname -s`"
  echo -e "${RESTORE}Dominio:${GREEN} `hostname -d`"
  echo -e "${RESTORE}"
}

#-----------------------------------------------------------------------

configura_hosts_file(){
  echo -e "\n###########################"
  echo -e "# Actualizando /etc/hosts #"
  echo -e "###########################\n"

  # Actualizacion del etc/hosts usando las variables definidas en el archivo de configuracion.
  cp ./Template_Files/hosts_template /etc/hosts
  sed -i "s/__IP__/$IPHelper/g" /etc/hosts
  sed -i "s/__HostName__/$HostName/g" /etc/hosts
  sed -i "s/__ShortHostName__/$ShortHostName/g" /etc/hosts

  # Muestreo del archivo /etc/hosts para comrpobar que está correcto"
  echo -e "# Archivo /etc/hosts actualizado: \n"
  cat /etc/hosts
  echo -e "\n"
}

#-----------------------------------------------------------------------

configura_seguridad(){
  echo -e "############################"
  echo -e "# Deshabilitando Seguridad #"
  echo -e "############################\n"

  # Deshabilitacion de firewalld y muestreo de estado.
  echo -e "# Desactivando firewall.\n"
  systemctl stop firewalld
  systemctl disable firewalld
  echo -e "# Firewall desactivado.\n"
  systemctl status firewalld |grep 'Loaded\|Active'

  # Deshabilitacion de Selinux y muestreo de estado.
  echo -e "\n# Desactivando SELINUX."
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  echo -e "# SELINUX desactivado."
  echo -e "# Estado de SELINUX: `getenforce`.\n"
}

#-----------------------------------------------------------------------

configura_ntp(){
  echo -e "#################################"
  echo -e "# Configurando Zona Horaria UTC #"
  echo -e "#################################\n"

  # Configuracion de Zona Horaria y muestreo de resultado.
  timedatectl set-timezone UTC
  echo -e "Fecha:${GREEN} `date`"
  echo -e "${RESTORE}"

  echo -e "##################################"
  echo -e "# Configuracion Del Servicio NTP #"
  echo -e "##################################\n"

  cp ./Template_Files/chrony.conf_template /etc/chrony.conf
  sed -i "s/__IPSEGMENT__/$IPSegment/g" /etc/chrony.conf
  sed -i "s/__NTPSERVER1__/$NTPSERVER1/g" /etc/chrony.conf
  sed -i "s/__NTPSERVER2__/$NTPSERVER2/g" /etc/chrony.conf
  sed -i "s/__NTPSERVER3__/$NTPSERVER3/g" /etc/chrony.conf
  sed -i "s/__NTPSERVER4__/$NTPSERVER4/g" /etc/chrony.conf

  systemctl restart chronyd
  systemctl enable chronyd
  echo -e "# Servicio NTP Configurado.\n"
  systemctl status chronyd |grep 'Loaded\|Active'
  echo -e "${GREEN}"
  chronyc sources
  echo -e "${RESTORE}"
}

#-----------------------------------------------------------------------

extra_conf(){
  # Configuracion de parametros del kernel.
  echo "user.max_user_namespaces=10000" > /etc/sysctl.d/42-rootless.conf
  sysctl -p
  # Creacion de la carpeta Data
  mkdir -p ${REGISTRY_BASE}/data
}

#-----------------------------------------------------------------------

config_general(){
  configura_repos;
  instala_paquetes;
  destarea_mirror;
  actualiza_hostname;
  configura_hosts_file;
  configura_seguridad;
  configura_ntp;
  extra_conf;
}

#-----------------------------------------------------------------------

###########################
#         BLOQUE          #
#           DE            #
#   FUNCIONES GENERICAS   #
###########################

#-----------------------------------------------------------------------

configura_dns_generico(){
  echo -e "##################################"
  echo -e "# Configuracion Del Servicio DNS #"
  echo -e "##################################\n"

  # Configuracion de DNS
  cp ./Template_Files/generic/generic_named.conf_template /etc/named.conf
  sed -i "s/__IP__/$IPHelper/g" /etc/named.conf
  sed -i "s/__DOMAIN__/$Domain/g" /etc/named.conf
  sed -i "s/__IPREV__/$IPRev/g" /etc/named.conf
  sed -i "s/__IP__/$IPHelper/g" /etc/named.conf

  cp ./Template_Files/generic/generic_resolv.conf_template /etc/resolv.conf
  sed -i "s/__IP__/$IPHelper/g" /etc/resolv.conf
  sed -i "s/__DOMAIN__/$Domain/g" /etc/resolv.conf
  
  # Configuracion de la zona DNS
  cp ./Template_Files/generic/generic.zone_template /var/named/$Domain.zone
  sed -i "s/__DOMAIN__/$Domain/g" /var/named/$Domain.zone
  sed -i "s/__IP__/$IPHelper/g" /var/named/$Domain.zone
  sed -i "s/__IPSEGMENT__/$IPSegment/g" /var/named/$Domain.zone
  sed -i "s/__ShortHostName__/$ShortHostName/g" /var/named/$Domain.zone
  
  # Configuracion de la zona reversa.
  cp ./Template_Files/generic/generic.rev.zone_template /var/named/$Domain.rev.zone
  sed -i "s/__DOMAIN__/$Domain/g" /var/named/$Domain.rev.zone
  sed -i "s/__IPREV__/$IPRev/g" /var/named/$Domain.rev.zone
  
  systemctl restart named
  systemctl enable named
  systemctl status named |grep 'Loaded\|Active'
}

#-----------------------------------------------------------------------

configura_dhcp_generico(){
  echo -e "\n###################################"
  echo -e "# Configuracion Del Servicio DHCP #"
  echo -e "###################################\n"

  cp ./Template_Files/generic/generic_dhcp.conf_template /etc/dhcp/dhcpd.conf   
  sed -i "s/__DOMAIN__/$Domain/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IP__/$IPHelper/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NETWORKMASK__/$NetworkMask/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NETWORKMASKOCTAL__/$NetworkMaskOctal/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPSEGMENT__/$IPSegment/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__HostName__/$HostName/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NTPSERVER1__/$NTPSERVER1/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NTPSERVER2__/$NTPSERVER2/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NTPSERVER3__/$NTPSERVER3/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__NTPSERVER4__/$NTPSERVER4/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACMASTER1__/$MAC_Master_01/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACMASTER2__/$MAC_Master_02/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACMASTER3__/$MAC_Master_03/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACWORKER1__/$MAC_Worker_01/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACWORKER2__/$MAC_Worker_02/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACWORKER3__/$MAC_Worker_03/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__MACBOOTSTRAP__/$MAC_Bootstrap/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPMASTER1__/$IP_Master_01/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPMASTER2__/$IP_Master_02/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPMASTER3__/$IP_Master_03/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPWORKER1__/$IP_Worker_01/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPWORKER2__/$IP_Worker_02/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPWORKER3__/$IP_Worker_03/g" /etc/dhcp/dhcpd.conf
  sed -i "s/__IPBOOTSTRAP__/$IP_Bootstrap/g" /etc/dhcp/dhcpd.conf

  systemctl restart dhcpd
  systemctl enable dhcpd
  systemctl status dhcpd |grep 'Loaded\|Active'
}

#-----------------------------------------------------------------------

configura_http(){
  echo -e "\n###################################"
  echo -e "# Configuracion Del Servicio HTTP #"
  echo -e "###################################\n"

  echo -e "# Creacion de carpetas necesarias."

  mkdir -p /var/www/html/ignition
  mkdir -p /var/www/html/img
  mkdir -p /var/www/html/pub/pxe

  tree /var/www/html

  echo -e "\n# Configuracion del servicio."
  sed -i 's/Listen 80$/Listen 8080/g'  /etc/httpd/conf/httpd.conf
  echo -e "\n# Copiando imagenes."
  cp ${REGISTRY_BASE}/downloads/images/*rootfs* /var/www/html/img

  echo -e "\n# Iniciando Servicio HTTP.\n"

  systemctl restart httpd
  systemctl enable httpd
  systemctl status httpd |grep 'Loaded\|Active'
}

#-----------------------------------------------------------------------

configura_tftp_generico(){
  echo -e "\n###################################"
  echo -e "# Configuracion Del Servicio TFTP #"
  echo -e "###################################\n"

  mkdir -p /var/lib/tftpboot/rhcos/
  mkdir -p /var/lib/tftpboot/pxelinux.cfg/

  \cp -f /tftpboot/* /var/lib/tftpboot/.

  cp -f ${REGISTRY_BASE}/downloads/images/${initramfs} /var/lib/tftpboot/rhcos/
  cp -f ${REGISTRY_BASE}/downloads/images/${kernel} /var/lib/tftpboot/rhcos/

  cp ./Template_Files/generic/generic_tftp_config_template /var/lib/tftpboot/pxelinux.cfg/default
  sed -i "s/__IP__/$IPHelper/g" /var/lib/tftpboot/pxelinux.cfg/default
  sed -i "s/__KERNEL__/$kernel/g" /var/lib/tftpboot/pxelinux.cfg/default
  sed -i "s/__INITRAMFS__/$initramfs/g" /var/lib/tftpboot/pxelinux.cfg/default

  systemctl restart tftp
  systemctl enable tftp
  systemctl status tftp |grep 'Loaded\|Active'
}

#-----------------------------------------------------------------------

configura_haproxy_generico(){
  echo -e "\n################################"
  echo -e "# Creacion de carpetas HAProxy #"
  echo -e "################################\n"

  mkdir -p /etc/haproxy/certs

  tree /etc/haproxy/

  cp ./Template_Files/generic/generic_haproxy.cfg_template /etc/haproxy/haproxy.cfg
  sed -i "s/__DOMAIN__/$Domain/g" /etc/haproxy/haproxy.cfg
  sed -i "s/__CLUSTERNAME__/$ClusterName/g" /etc/haproxy/haproxy.cfg

  sed -i '/After.*/a After=named.service' /usr/lib/systemd/system/haproxy.service

  echo -e "\n# Iniciando Servicio HAProxy.\n"

  systemctl daemon-reload
  systemctl restart haproxy
  systemctl enable haproxy
  systemctl status haproxy |grep 'Loaded\|Active'
}

#-----------------------------------------------------------------------

####################
#      BLOQUE      #
#        DE        #
#     FUNCIONES    #
#        DE        #
#   CERTIFICADOS   #
#        Y         #
#      MIRROR      #
####################

#-----------------------------------------------------------------------

configura_certs(){
  echo -e "\n############################"
  echo -e "# Creacion de certificados #"
  echo -e "############################\n"

  # Creacion de certificados ssh.

  if [ ! -f /root/.ssh/id_rsa.pub ];
  then
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
  fi

  rm -rf $REGISTRY_BASE/certs/*

  # Creacion del archivo /opt/registry/certs/csr_answer.txt
  cp ./Template_Files/certificates/csr_answer.txt_template $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__PAIS__/$PAIS/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__COMUNIDAD__/$COMUNIDAD/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__PROVINCIA__/$PROVINCIA/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__EMPRESA__/$EMPRESA/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__DEPARTAMENTO__/$DEPARTAMENTO/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__emailAddress__/$emailAddress/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__HostName__/$HostName/g" $REGISTRY_BASE/certs/csr_answer.txt
  sed -i "s/__ShortHostName__/$ShortHostname/g" $REGISTRY_BASE/certs/csr_answer.txt

  # Creacion del archivo /opt/registry/certs/domain.ext
  cp ./Template_Files/certificates/domain.ext_template $REGISTRY_BASE/certs/domain.ext
  sed -i "s/__HostName__/$HostName/g" $REGISTRY_BASE/certs/domain.ext
  sed -i "s/__ShortHostName__/$ShortHostname/g" $REGISTRY_BASE/certs/domain.ext

  echo -e "# Creacion de ca.crt${GREEN}\n"

  openssl req -newkey rsa:4096 -nodes -sha256 -keyout $REGISTRY_BASE/certs/ca.key -x509 -subj "/C=$PAIS/ST=$COMUNIDAD/L=$PROVINCIA/O=$EMPRESA/OU=$DEPARTAMENTO/CN=$HostName" -days 36500 -out $REGISTRY_BASE/certs/ca.crt

  echo -e "\n${RESTORE}# Creacion de domain.key y domain.csr${GREEN}\n"

  openssl req -newkey rsa:4096 -nodes -sha256 -keyout $REGISTRY_BASE/certs/domain.key -out $REGISTRY_BASE/certs/domain.csr -days 36500 -config <( cat $REGISTRY_BASE/certs/csr_answer.txt )

  echo -e "\n${RESTORE}# Creacion de ca.key${GREEN}\n"

  openssl x509 -req -days 36500 -in $REGISTRY_BASE/certs/domain.csr -CA $REGISTRY_BASE/certs/ca.crt -CAkey $REGISTRY_BASE/certs/ca.key -CAcreateserial -out $REGISTRY_BASE/certs/domain.crt -extfile $REGISTRY_BASE/certs/domain.ext

  echo -e "\n${RESTORE}# Actualizacion de ca.crt general\n"

  \cp -f ${REGISTRY_BASE}/certs/ca.crt ${REGISTRY_BASE}/certs/${HostName}.crt
  rm -f /etc/pki/ca-trust/source/anchors/${HostName}.crt
  cp ${REGISTRY_BASE}/certs/${HostName}.crt /etc/pki/ca-trust/source/anchors/
  
  update-ca-trust
  update-ca-trust extract
}

#-----------------------------------------------------------------------

configura_registry(){
  echo -e "\n##############################"
  echo -e "# Creacion de registry local #"
  echo -e "##############################\n"

  echo -e "${RESTORE}# Creacion de htpasswd${GREEN}\n"
  htpasswd -bBc ${REGISTRY_BASE}/auth/htpasswd $HttpUser $HttpPasswd
  echo -e "${RESTORE}"

  # Creacion del pod del registry local.

  cp ./Scripts/start_registry.sh ${REGISTRY_BASE}/downloads/tools/start_registry.sh
  sed -i "s@__REGISTRYBASE__@$REGISTRY_BASE@g" ${REGISTRY_BASE}/downloads/tools/start_registry.sh

  chmod a+x ${REGISTRY_BASE}/downloads/tools/start_registry.sh

  echo -e "${RESTORE}# Carga de la imagen del registry.${GREEN}\n"

  podman load < ${REGISTRY_BASE}/downloads/images/registry.tar

  echo -e "${RESTORE}\n# Arranque del registry local.${GREEN}\n"

  podman run --name my-registry --rm -d -p 5000:5000 -v ${REGISTRY_BASE}/data:/var/lib/registry:z -v ${REGISTRY_BASE}/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v ${REGISTRY_BASE}/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key docker.io/library/registry:2
  
  podman ps
  echo -e "${RESTORE}"
}

#-----------------------------------------------------------------------

carga_imagenes(){
  echo -e "################################"
  echo -e "# Carga de imagenes de RedHat. #"
  echo -e "################################\n"

  # Definicion de secrets para la correcta carga de imágenes.
  cp pull-secret.json ${REGISTRY_BASE}/downloads/secrets/pull-secret.json
  cat ${REGISTRY_BASE}/downloads/secrets/pull-secret.json | jq '.auths += {"'${HostName}':5000": {"auth": "REG_SECRET","email": "'${emailAddress}'"}}' | sed "s/REG_SECRET/$REG_SECRET/" > ${REGISTRY_BASE}/downloads/secrets/pull-secret-bundle.json
  echo '{ "auths": {}}' | jq '.auths += {"'${HostName}':5000": {"auth": "REG_SECRET","email": "'${emailAddress}'"}}' | sed "s/REG_SECRET/$REG_SECRET/" | jq -c .> ${REGISTRY_BASE}/downloads/secrets/pull-secret-registry.json

  tar -xzvf ${REGISTRY_BASE}/downloads/tools/openshift-client*.tar.gz -C /usr/local/bin

  oc image mirror -a ${REGISTRY_BASE}/downloads/secrets/pull-secret-registry.json --from-dir=/opt/mirror "file://openshift/release:${imageVersion}*" ${HostName}:5000/ocp/openshift4

  tar -xzvf ${REGISTRY_BASE}/downloads/tools/helm-linux-amd64.tar.gz -C /tmp
  \cp /tmp/helm-linux-amd64 /usr/local/bin/helm
}

#-----------------------------------------------------------------------

configura_install_config(){
  echo -e "\n################################"
  echo -e "# CONFIGURACION INSTALL-CONFIG #"
  echo -e "################################\n"

  cp ./Template_Files/install-config.yaml_template ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  # Sustitución de variables.
  sed -i "s/__DOMAIN__/$Domain/g" ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  sed -i "s/__CLUSTERNAME__/$ClusterName/g" ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  sed -i "s/__IPSegment__/$IPSegment/g" ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  sed -i "s/__NetworkMaskOctal__/$NetworkMaskOctal/g" ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  # Adicion del pull-secret, clave ssh y certificados para una correcta instalacion.
  echo -n "pullSecret: '" >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml && echo '{ "auths": {}}' | jq '.auths += {"'${HostName}':5000": {"auth": "REG_SECRET","email": "'${emailAddress}'"}}' | sed "s/REG_SECRET/$REG_SECRET/" | jq -c . | sed "s/$/\'/g" >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  echo -n "sshKey: '" >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml && cat ~/.ssh/id_rsa.pub | sed "s/$/\'/g" >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  echo "additionalTrustBundle: |" >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  cat ${REGISTRY_BASE}/certs/ca.crt | sed 's/^/\ \ \ \ \ /g' >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml
  cat ${REGISTRY_BASE}/downloads/secrets/mirror-output.txt | grep -A7 imageContentSources >> ${REGISTRY_BASE}/downloads/tools/install-config.yaml
}

#-----------------------------------------------------------------------

configura_ignition_files(){
  cp ./Scripts/clean.sh ${REGISTRY_BASE}/downloads/tools/clean.sh
  sed -i "s@__REGISTRYBASE__@$REGISTRY_BASE@g" ${REGISTRY_BASE}/downloads/tools/clean.sh

  chmod 700 ${REGISTRY_BASE}/downloads/tools/clean.sh

  rm -rf /root/cluster
  mkdir /root/cluster
  
  cp ${REGISTRY_BASE}/downloads/tools/install-config.yaml /root/cluster
  ${REGISTRY_BASE}/downloads/tools/openshift-install create manifests --dir=/root/cluster
  ${REGISTRY_BASE}/downloads/tools/openshift-install create ignition-configs --dir=/root/cluster
  cp /root/cluster/*ign /var/www/html/ignition
  chmod o+r /var/www/html/ignition/*ign
}

#-----------------------------------------------------------------------

####################
#      BLOQUE      #
#        DE        #
#   FUNCION MAIN   #
####################

main(){
  config_general;
  # Variables Para Imagenes
  kernel=`ls /opt/registry/downloads/images/*kernel* |cut -d"/" -f 6`
  initramfs=`ls /opt/registry/downloads/images/*initram* | cut -d"/" -f 6`
  rootfs=`ls /opt/registry/downloads/images/*rootfs* | cut -d"/" -f 6`
  configura_dns_generico;
  configura_dhcp_generico;
  configura_http;
  configura_tftp_generico;
  configura_haproxy_generico;
  configura_certs;
  configura_registry;
  carga_imagenes;
  configura_install_config;
  configura_ignition_files;
}

main;

echo -e "\n${GREEN}#######################"
echo -e "# Proceso Completado. #"
echo -e "#######################\n${RESTORE}"

exit;