# INSTRUCCIONES DE USO

Esta tool esta diseñada para la creación de OCPs en entornos desconectados.
Para utilizarla se ejecuta el script main.sh indicando como parámetro si se quiere crear un mirror o configurar el entorno desconectado de la siguiente manera:

./main.sh online (Para la creacion del mirror.)
./main.sh offline (Para la configuracion del entorno desconectado.)

Este script a su vez llama a los scripts situados en la carpeta "Scripts" configura_offline.sh o crea_mirror.sh en función del parámetro anterior.
También puede ser utilizada para realizar una actualización desconectada de OCP, para ello se debe ejecutar de la siguiente manera:

./main.sh online update (Para la creacion del mirror de la update.)
./main.sh offline update (Para la configuracion del entorno desconectado y la ejecución de la actualziación de manera automática.)

Este script a su vez llama a los scripts situados en la carpeta "Scripts" configura_update_offline.sh o crea_update_mirror.sh en función de los parámetros anteriores.

## Necesidades Uso Online

Para realizar el mirror es necesario tener una suscripción activa a RedHat, tener la máquina registrada a la suscripción y conexión a internet.
Además se debera tener el pull-secret necesario para realizar la descarga de la paquetería necesaria.

Comando para la suscirpción: subscription-manager register --username <username> --password <password> --auto-attach

Link para copiar el pull-secret: https://console.redhat.com/openshift/downloads

El pull-secret se copiará de la web anterior y se pegará dentro del archivo pull-secret

## Necesidades Uso Offline

Para realizar la instalación y configuración offline es necesario tener una ISO del Sistema Operativo de la máquina montada sobre /mnt.
Esto es necesario para la correcta instalación de los paquetes necesarios por el script y el propio OCP.
Además, se deberá tener el archivo .tar generado con la función online ubicado en la raíz del sistema.

## Archivo De Configuración

Para indicar los datos con los que se desea realiazar la instalación y la configuración se debe modificar el archivo full_config.conf.
En este archivo se detallan las variables con los datos necesarios para las acciones que realizan los scripts anteriormente mencionados.

## Archivos de templatizado de servicios.

Para que sea más sencilla la configuración de los servicios se utilzan varios archivos plantilla situados en la carpeta "Template_Files".
Estos archivos a priori no deberían tocarse a menos que se requiera una configuración específica no definida por defecto en los mismos.
Los valores necesarios dentro de estas plantillas se modifican en tiempo de ejecución de manera automática y no necesita de intervención por parte del usuario.

