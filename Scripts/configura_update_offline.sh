#!/bin/bash

# Carga de Variables Desde Archivo.
source ./full_config.conf

# Comprobacion de los datos de las variables.
echo -e "${RESTORE}"
echo -e "#########################################"
echo -e "# Compruebe si los datos son correctos: #"
echo -e "#########################################\n"
echo -e "${RESTORE}Directorio update base:${GREEN} $UPDATE_BASE"
echo -e "${RESTORE}Directorio update registry:${GREEN} $UPDATE_REGISTRY_BASE"
echo -e "${RESTORE}Hostname:${GREEN} $HostName"
echo -e "${RESTORE}Nombre del cluster:${GREEN} $ClusterName"
echo -e "${RESTORE}Dominio:${GREEN} $Domain"
echo -e "${RESTORE}Usuario Registry:${GREEN} $HttpUser"
echo -e "${RESTORE}Contraseña Registry:${GREEN} $HttpPasswd"
echo -e "${RESTORE}Version update de OCP:${GREEN} $UPDATE_OCP_RELEASE"
echo -e "${RESTORE}Version de helm:${GREEN} $HELM"
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

destarea_mirror(){
  echo -e "\n###################################"
  echo -e "# Destareando archivos necesarios #"
  echo -e "###################################\n"

  find / -iname "*UPDATE*-registry.tar.gz" -exec tar -xvzf "{}" -C / \;
}

#-----------------------------------------------------------------------

HostName=`hostname`
ShortHostName=`hostname -s`
LongDomain=`hostname -d`

#-----------------------------------------------------------------------

update_registry(){
  echo -e "########################"
  echo -e "# Destareo De Binarios #"
  echo -e "########################\n"
  
  tar -xvzf ${UPDATE_REGISTRY_BASE}/downloads/tools/openshift-client-linux-${UPDATE_OCP_RELEASE}.tar.gz -C /usr/bin/
  cp ${UPDATE_REGISTRY_BASE}/downloads/tools/openshift-install /usr/bin/
  
  UPGRADE_IMAGE_ROUTE=$(openshift-install version |grep "release image" |cut -d" " -f 3 |cut -d"/" -f 2,3 |cut -d"@" -f 1)
  UPGRADE_IMAGE=$(openshift-install version |grep "release image" |cut -d" " -f 3)

  echo -e "################################"
  echo -e "# Carga de imagenes de RedHat. #"
  echo -e "################################\n"
 
  podman login -u ${HttpUser} -p ${HttpPasswd} https://${HostName}:5000
  oc image mirror --from-dir=${UPDATE_BASE}/mirror/ file://openshift/release:${UPDATE_OCP_RELEASE}* ${HostName}:5000/${UPGRADE_IMAGE_ROUTE} --keep-manifest-list=true --insecure

  echo -e "##################################"
  echo -e "# Aplicacion de Configuraciones  #"
  echo -e "##################################\n"

  oc apply -f ${UPDATE_BASE}/mirror/config/*.json
  oc -n openshift-config patch cm admin-acks --patch '{"data":{"ack-4.13-kube-1.27-api-removals-in-4.14":"true"}}' --type=merge

  echo -e "###############################"
  echo -e "# Aplicacion de Actualizacion #"
  echo -e "###############################\n"

  oc adm upgrade --allow-explicit-upgrade --to-image ${UPGRADE_IMAGE}

}

#-----------------------------------------------------------------------

####################
#      BLOQUE      #
#        DE        #
#   FUNCION MAIN   #
####################

main(){
  # Variables Para Imagenes
  case $TYPE in
    generic)
    destarea_mirror
    update_registry
    ;;
    itec)
    destarea_mirror
    update_registry
    ;;
    neo)
    destarea_mirror
    update_registry
    ;;
    *)
    echo -e "Tipo De Instalación Incorrecto.\nLos tipos soportados son: ${GREEN}generic, itec o neo.${RESTORE}"
    ;;
  esac

}

main;

echo -e "\n${GREEN}#######################"
echo -e "# Proceso Completado. #"
echo -e "#######################\n${RESTORE}"

exit;
