#!/bin/bash

# Variables de configuración
source ./full_config.conf

AUTH="$HttpUser:$HttpPasswd"
VERSION_PREFIX="$OCP_RELEASE-x86_64"
LOGFILE="/root/registry_cleanup_$(date +%Y%m%d_%H%M%S).log"

# Comprobacion de los datos de las variables.
echo -e "${YELLOW}"
echo -e "##########################################################################################################"
echo -e "# ATENCION: LA VERSION DE OCP SIGUIENTE SERA ELIMINADA, POR FAVOR COMPRUEBE LOS DATOS ANTES DE PROCEDER. #\n#                                 ESTA ACCIÓN NO SE PUEDE DESHACER.                                      #"
echo -e "##########################################################################################################\n"
echo -e "${RESTORE}Registry Afectado:${GREEN} $LOCAL_REGISTRY"
echo -e "${RESTORE}Version a Eliminar:${GREEN} $VERSION_PREFIX"
echo -e "${RESTORE}Repositorio a eliminar:${GREEN} $LOCAL_REPOSITORY"
echo -e "${RESTORE}"

# Logica para permitir cortar la ejecucion en caso de que las variables sean incorrectas.
echo "¿Son correctas las variables? (Y/N)";read RESPUESTA
if [[ $RESPUESTA != [Yy] ]];
then
    exit;
fi

echo "🗂️  Registro de borrado iniciado: $LOGFILE" | tee -a "$LOGFILE"

# Obtener todos los tags que empiezan con esa versión
tags=$(curl -u $AUTH -s https://$LOCAL_REGISTRY/v2/$LOCAL_REPOSITORY/tags/list | jq -r ".tags[] | select(startswith(\"$VERSION_PREFIX\"))")

for tag in $tags; do
  echo "🔄 Procesando tag: $tag" | tee -a "$LOGFILE"

  DIGEST=""
  for accept_header in \
    "application/vnd.docker.distribution.manifest.v2+json" \
    "application/vnd.docker.distribution.manifest.list.v2+json" \
    "application/vnd.oci.image.manifest.v1+json"
  do
    DIGEST=$(curl -u $AUTH -sI \
      -H "Accept: ${accept_header}" \
      https://$LOCAL_REGISTRY/v2/$LOCAL_REPOSITORY/manifests/$tag | \
      grep -i Docker-Content-Digest | awk '{print $2}' | tr -d $'\r')

    if [ -n "$DIGEST" ]; then
      echo "  ✅ Digest encontrado con header ${accept_header}: $DIGEST" | tee -a "$LOGFILE"
      break
    fi
  done

  if [ -n "$DIGEST" ]; then
    echo "  🚮 Enviando DELETE para digest: $DIGEST" | tee -a "$LOGFILE"

    DELETE_RESPONSE=$(curl -u $AUTH -s -o /dev/null -w "%{http_code}" -X DELETE \
      https://$LOCAL_REGISTRY/v2/$LOCAL_REPOSITORY/manifests/$DIGEST)

    if [ "$DELETE_RESPONSE" == "202" ]; then
      echo "  ✅ Imagen eliminada con éxito (HTTP $DELETE_RESPONSE)" | tee -a "$LOGFILE"
    else
      echo "  ❌ Fallo al eliminar imagen (HTTP $DELETE_RESPONSE)" | tee -a "$LOGFILE"
    fi
  else
    echo "  ⚠️  No se pudo obtener digest para $tag" | tee -a "$LOGFILE"
  fi
done

echo "🚮 Ejecutando registry garbage-collect:" | tee -a "$LOGFILE"

podman exec -it my-registry registry garbage-collect -m /etc/docker/registry/config.yml  

echo "✅ Proceso completado. Ver log: $LOGFILE"
