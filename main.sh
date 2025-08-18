#!/bin/bash

#Lista de colores para el terminal
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

# Funcion con las instrucciones basicas.
help(){
    echo -e "${CYAN}\n########################"
    echo -e "# Instrucciones De Uso #"
    echo -e "########################\n${RESTORE}"
    echo -e "- Para utilizar el siguiente script se debera indicar una de las siguientes opciones: ${GREEN}online ${RESTORE}u ${GREEN}offline${RESTORE}.\n"
    echo -e "- ${GREEN}Online:${RESTORE} Indicara la creacion del archivo .tar.gz para una instalacion desconectada.\n  ${YELLOW}ATENCION: ${RESTORE}Para esta opcion necesitara conexion a internet asi como una suscripcion activa de redhat.\n"
    echo -e "- ${GREEN}Offline:${RESTORE} Utilizado para configurar la maquina bastion desconectada.\n  ${YELLOW}ATENCION: ${RESTORE}Esta opcion necesita tener una iso del SO instalado montada sobre /mnt para un correcto funcionamiento.\n"
    echo -e "- Ejemplo de ejecución:\n${GREEN}# ./main.sh offline${RESTORE}\n"
    echo -e "- Para utilizar el siguiente script para actualizar un ocp se debera indicar la opcion ${GREEN}update${RESTORE} despues del tipo de instalacion.${RESTORE}\n"
    echo -e "- Ejemplo de ejecución:\n${GREEN}# ./main.sh online update${RESTORE} # Creara un archivo .tar.gz para la actualizacion desconectada.\n"
    echo -e "- Ejemplo de ejecución:\n${GREEN}# ./main.sh offline update${RESTORE} # Ejecutara la actualizacion desconectada.\n"
    echo -e "- En caso de mas dudas, se recomienda leer el archivo ${YELLOW}README.MD${RESTORE}\n"
exit;
}

# Funcion principal que llama a los scripts necesarios.
main(){
    if [[ $# = 1 ]];
    then
    	if [[ "$1" == "online" ]];
    	then
        	source ./Scripts/crea_mirror.sh
        	exit;
    	elif [[ "$1" == "offline" ]];
    	then
        	source ./Scripts/configura_offline.sh
        	exit;
    	else
        	help
    	fi
    elif [[ $# = 2 ]];
    then
    	if [[ "$1" == "online" ]] && [[ "$2" == "update" ]];
    	then
        	source ./Scripts/crea_update_mirror.sh
        	exit;
    	elif [[ "$1" == "offline" ]] && [[ "$2" == "update" ]];
    	then
        	source ./Scripts/configura_update_offline.sh
        	exit;
    	else
        	help
    	fi
    else
        help
    fi
}

# Comprobacion del numero de variables para un correcto funcionamiento.
#if [[ $# != 1 ]] || [[ $# != 2 ]];
#then
#    help
#fi

# Llamada de la funcion main con el parametro pasado en la ejecucion del script.
main $1 $2
