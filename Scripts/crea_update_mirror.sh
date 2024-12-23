#!/bin/bash

# Carga de Variables Desde Archivo.
source ./full_config.conf

#Comprobacion de los datos de las variables.
echo -e "${RESTORE}"
echo -e "#########################################"
echo -e "# Compruebe si los datos son correctos: #"
echo -e "#########################################\n"
echo -e "${RESTORE}Directorio update base:${GREEN} $BASE"
echo -e "${RESTORE}Directorio update registry:${GREEN} $UPDATE_REGISTRY_BASE"
echo -e "${RESTORE}Redhat Secret:\n${GREEN}$SECRET"
echo -e "${RESTORE}Direccion de email:${GREEN} $emailAddress"
echo -e "${RESTORE}Hostname:${GREEN} $HostName"
echo -e "${RESTORE}Nombre del cluster:${GREEN} $ClusterName"
echo -e "${RESTORE}Dominio:${GREEN} $Domain"
echo -e "${RESTORE}Usuario Registry:${GREEN} $HttpUser"
echo -e "${RESTORE}Contraseña Registry:${GREEN} $HttpPasswd"
echo -e "${RESTORE}Version update de OCP:${GREEN} $UPDATE_OCP_RELEASE"
echo -e "${RESTORE}Version de helm:${GREEN} $HELM"
echo -e "${RESTORE}Pais:${GREEN} $PAIS"
echo -e "${RESTORE}Comunidad: ${GREEN} $COMUNIDAD"
echo -e "${RESTORE}Provincia: ${GREEN} $PROVINCIA"
echo -e "${RESTORE}Empresa: ${GREEN} $EMPRESA"
echo -e "${RESTORE}Departamento: ${GREEN} $DEPARTAMENTO"
echo -e "${RESTORE}"
#Logica para permitir cortar la ejecucion en caso de que las variables sean incorrectas.
echo "¿Son correctas las variables? (Y/N)";read RESPUESTA
if [[ $RESPUESTA != [Yy] ]];
then
    exit;
fi

limpia_entorno(){
  echo -e "\n#######################################"
  echo -e "# Preparando Entorno Para Instalación #"
  echo -e "#######################################\n"

  # Borra el contenido de la carpeta /update
  rm -rf /update/mirror /update/registry /update/redhat-release
  rm -rf /root/.ssh/*
  rm -rf /root/cluster/
  REGISTRY_POD=`podman ps -a |cut -d" " -f 1|grep -v CONTAINER`
  podman stop ${REGISTRY_POD}
  podman rm ${REGISTRY_POD}
}

limpia_entorno

#Instalacion de paquetes con yum.
echo -e "\n##################################"
echo -e "# Instalando paquetes requeridos #"
echo -e "##################################\n"
pkgs="jq openssl podman httpd-tools curl wget chrony tree"
yum install $pkgs -y

echo -e "\n#########################"
echo -e "# Actualizando Hostname #"
echo -e "#########################\n"

#Actualizacion de hostname y dominio en base al archivo de variables.
hostname $HostName.$ClusterName.$Domain
hostnamectl set-hostname $HostName.$ClusterName.$Domain

#Muestreo del resultado.
echo -e "${RESTORE}Hostname completo:${GREEN} `hostname`"
echo -e "${RESTORE}Hostname corto:${GREEN} `hostname -s`"
echo -e "${RESTORE}Dominio:${GREEN} `hostname -d`"
echo -e "${RESTORE}"

echo -e "\n###########################"
echo -e "# Actualizando /etc/hosts #"
echo -e "###########################\n"

#Actualizacion del etc/hosts usando la variable anterior y las definidas en el archivo de variables.
cat > /etc/hosts << EOF
127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
$IPHelper $HostName.$ClusterName.$Domain $HostName
EOF

#Muestreo del archivo /etc/hosts para comrpobar que está correcto"
echo -e "# Archivo /etc/hosts actualizado: \n"
cat /etc/hosts
echo -e "\n"

echo -e "############################"
echo -e "# Deshabilitando Seguridad #"
echo -e "############################\n"

#Deshabilitacion de firewalld y muestreo de estado.
echo -e "# Desactivando firewall.\n"
systemctl stop firewalld
systemctl disable firewalld
echo -e "# Firewall desactivado.\n"
systemctl status firewalld |grep 'Loaded\|Active'

#Deshabilitacion de Selinux y muestreo de estado.
echo -e "\n# Desactivando SELINUX."
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo -e "# SELINUX desactivado."
echo -e "# Estado de SELINUX: `getenforce`.\n"

echo -e "#################################"
echo -e "# Configurando Zona Horaria UTC #"
echo -e "#################################\n"

#Configuracion de Zona Horaria y muestreo de resultado.
timedatectl set-timezone UTC
echo -e "Fecha:${GREEN} `date`"
echo -e "${RESTORE}"

echo -e "###################################"
echo -e "# Creacion de carpetas necesarias #"
echo -e "###################################\n"

#Creacion de carpetas en cascada.
mkdir -p ${UPDATE_BASE}
mkdir -p ${UPDATE_REGISTRY_BASE}
mkdir -p ${UPDATE_BASE}/mirror
mkdir -p ${UPDATE_REGISTRY_BASE}/{auth,certs,data,downloads}
mkdir -p ${UPDATE_REGISTRY_BASE}/downloads/{images,tools,secrets}
tree $UPDATE_REGISTRY_BASE

#Reasignación de variable hostname para creación de certificados.

HostName=`hostname`

#Creacion de certificados.

rm -rf $UPDATE_REGISTRY_BASE/certs/*

echo -e "\n############################"
echo -e "# Creacion de certificados #"
echo -e "############################\n"

#Creacion del archivo /update/registry/certs/csr_answer.txt
cat > $UPDATE_REGISTRY_BASE/certs/csr_answer.txt << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
x509_extensions = req_ext
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C=$PAIS
ST=$COMUNIDAD
L=$PROVINCIA
O=$EMPRESA
OU=$DEPARTAMENTO
emailAddress=$emailAddress
CN = $HostName
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $HostName
EOF

#Creacion del archivo /update/registry/certs/domain.ext
cat > $UPDATE_REGISTRY_BASE/certs/domain.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $HostName
EOF

echo -e "# Creacion de ca.crt"
echo -e "${GREEN}"

openssl req -newkey rsa:4096 -nodes -sha256 -keyout $UPDATE_REGISTRY_BASE/certs/ca.key -x509 -subj "/C=$PAIS/ST=$COMUNIDAD/L=$PROVINCIA/O=$EMPRESA/OU=$DEPARTAMENTO/CN=$HostName" -days 36500 -out $UPDATE_REGISTRY_BASE/certs/ca.crt

echo -e "${RESTORE}"
echo -e "# Creacion de domain.key y domain.csr"
echo -e "${GREEN}"

openssl req -newkey rsa:4096 -nodes -sha256 -keyout $UPDATE_REGISTRY_BASE/certs/domain.key -out $UPDATE_REGISTRY_BASE/certs/domain.csr -days 36500 -config <( cat $UPDATE_REGISTRY_BASE/certs/csr_answer.txt )

echo -e "${RESTORE}"
echo -e "# Creacion de ca.key"
echo -e "${GREEN}"

openssl x509 -req -days 36500 -in $UPDATE_REGISTRY_BASE/certs/domain.csr -CA $UPDATE_REGISTRY_BASE/certs/ca.crt -CAkey $UPDATE_REGISTRY_BASE/certs/ca.key -CAcreateserial -out $UPDATE_REGISTRY_BASE/certs/domain.crt -extfile $UPDATE_REGISTRY_BASE/certs/domain.ext

echo -e "${RESTORE}"
echo -e "# Actualizacion de ca.crt general"

\cp -f ${UPDATE_REGISTRY_BASE}/certs/ca.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

echo -e "${RESTORE}"
echo -e "# Creacion de htpasswd"
echo -e "${GREEN}"

htpasswd -bBc ${UPDATE_REGISTRY_BASE}/auth/htpasswd $HttpUser $HttpPasswd
echo -e "${RESTORE}"

echo -e "##############################"
echo -e "# Creacion de registry local #"
echo -e "##############################"

#Creacion del pod del registry local.
echo -e "${GREEN}"
podman run --name my-registry --rm -d -p 5000:5000 \
-v ${UPDATE_REGISTRY_BASE}/data:/var/lib/registry:z \
-v ${UPDATE_REGISTRY_BASE}/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v ${UPDATE_REGISTRY_BASE}/certs:/certs:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2

podman ps
echo -e "${RESTORE}"

#Descarga de Imagenes y Paquetes necesarios de RedHat.

echo -e "###################################"
echo -e "# Descarga de archivos de RedHat. #"
echo -e "###################################\n"

echo -e "# Descarga de tooles de OC.\n${GREEN}"
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${UPDATE_OCP_RELEASE}/openshift-client-linux-${UPDATE_OCP_RELEASE}.tar.gz -P ${UPDATE_REGISTRY_BASE}/downloads/tools/

echo -e "${RESTORE}# Extraccion de tooles de OC.\n${GREEN}"
tar -xvzf $UPDATE_REGISTRY_BASE/downloads/tools/openshift-client-linux-${UPDATE_OCP_RELEASE}.tar.gz -C /usr/local/bin

echo -e "${RESTORE}# Descarga de Helm.\n${GREEN}"
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/helm/${HELM}/helm-linux-amd64.tar.gz -P ${UPDATE_REGISTRY_BASE}/downloads/tools/

echo -e "${RESTORE}# Extraccion de helm.\n${GREEN}"
tar -xvzf $UPDATE_REGISTRY_BASE/downloads/tools/helm-linux-amd64.tar.gz -C /usr/local/bin/
mv /usr/local/bin/helm-linux-amd64 /usr/local/bin/helm
echo -e "${RESTORE}"

#Definicion de variables para creacion de mirror.

cd ${UPDATE_REGISTRY_BASE}/downloads/secrets/
cat > pull-secret.json << EOF 
${SECRET}
EOF
cat pull-secret.json | jq '.auths += {"'${HostName}':5000": {"auth": "REG_SECRET","email": "'${emailAddress}'"}}' | sed "s/REG_SECRET/$REG_SECRET/" > pull-secret-bundle.json
echo '{ "auths": {}}' | jq '.auths += {"'${HostName}':5000": {"auth": "REG_SECRET","email": "'${emailAddress}'"}}' | sed "s/REG_SECRET/$REG_SECRET/" | jq -c .> pull-secret-registry.json

echo -e "######################################"
echo -e "# Descarga de imagenes de OpenShift. #"
echo -e "######################################\n"

oc adm -a ${LOCAL_SECRET_JSON} release mirror \
--from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${UPDATE_OCP_RELEASE_ARCH} \
--to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
--to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${UPDATE_OCP_RELEASE_ARCH} \
--to-dir=/update/mirror > ${UPDATE_REGISTRY_BASE}/downloads/secrets/mirror-output.txt

oc adm -a ${LOCAL_SECRET_JSON} release mirror \
--from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${UPDATE_OCP_RELEASE_ARCH} \
--to-dir=/update/mirror

cd ${UPDATE_REGISTRY_BASE}/downloads/tools/

echo -e "\n##############################################"
echo -e "# Descarga de instalador local de OpenShift. #"
echo -e "##############################################\n"

oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${UPDATE_OCP_RELEASE_ARCH}"

echo -e "\n###############################################"
echo -e "# Guardado de Registry para uso desconectado. #"
echo -e "###############################################\n"

podman stop my-registry

podman save docker.io/library/registry:2 -o ${UPDATE_REGISTRY_BASE}/downloads/images/registry.tar

echo -e "\n###################################################"
echo -e "# Guardado de archivo .tar para uso desconectado. #"
echo -e "###################################################\n"

cd /
cp /etc/redhat-release /update
VERSION_OS=`cat /etc/redhat-release|cut -d ' ' -f6 `
fecha=`date +%Y%m%d%H%M%S`
tar --exclude ${UPDATE_REGISTRY_BASE}/data/*  -vzcf ${VERSION_OS}-${fecha}-UPDATE-${UPDATE_OCP_RELEASE_ARCH}-registry.tar.gz /update

display_mensaje(){
    echo -e "\n${GREEN}#######################"
    echo -e "# Proceso Completado. #"
    echo -e "#######################\n${RESTORE}"
}

case $TYPE in
    generic)
    display_mensaje
    ;;
    itec)
    display_mensaje
    ;;
    neo)
    display_mensaje
    ;;
    *)
    echo -e "Tipo De Instalación Incorrecto.\nLos tipos soportados son: ${GREEN}generic, itec o neo.${RESTORE}"
    ;;
esac
