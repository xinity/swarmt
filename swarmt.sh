#!/bin/bash
# shellcheck disable=SC1090,SC2086
set -x
# ------------------------   Introduction   --------------------------------- #
#
# Name : swarmt.sh
#
# Description : Deploy and manage your swarm clusters using docker-machine
#
# Syntaxe : swarmt.sh
#
# Arguments:
#            init   : create and initialize swarm cluster
#            start : start an existing swarm cluster
#            list   : list existing nodes based of config files
#            stop  : Halt every swarm nodes
#            rm    : delete the swarm cluster
# Options:
#             -c [configuration file]: optional configuration file
# --------------------------------------------------------------------------- #

#Initialize variables
CURRENT_DIR="$(pwd -P)"
cfg_file="$(echo ${0##*/} | sed 's/.sh/.conf/g')"

# Interactive documentation
usage() {
  echo " "
  echo "=================================================="
  echo " $(basename ${0}) takes arguments described below:"
  echo "    -h    : show this help box "
  echo "    init  : create and initialize swarm cluster "
  echo "    start : start an existing swarm cluster "
  echo "    list  : list all existing nodes "
  echo "    stop  : Halt every swarm nodes "
  echo "    rm    : delete the swarm cluster "
  echo " "
  echo " You can pass a specific configuration file:"
  echo " ./swarmt.sh -c swarm.conf init"
  echo " "
  echo " By default the script will be looking "
  echo " for a config file named: swarmt.conf "
  echo "=================================================="
  exit 0
}


# Ability to pass command while creating machines
machines_commands(){
  if [ -f "${2}" ]
  then
    while IFS= read -r line
    do
      docker-machine ssh ${1} "$line" </dev/null
      sleep 5
    done < ${2}
  fi
}

# Up scaling Swarm cluster
scaler(){
symbol=${1::1}
number=${1:1:2}
if [ "${symbol}" == u ]
then
  echo "sens : ${symbol} et nombre: ${number}"
  #TODO: recuperer le numéro le plus haut des workers et incrementer 
  sworker=$(grep sworker )
  echo "create_machines ${sworker}=$((sworker+=1))"
        create_machines ${project}w${nw}

elif [[ "${symbol}" == d ]]; then
  worker=${1:1:2}
  echo "sens : ${symbol} et nombre: ${number}
  eval $(docker-machine env ${worker})
  docker node update --availability drain ${worker}
  docker node rm ${worker}
  "
fi
}

menu_scale(){
  while true; do
    read -r -p "how many nodes ?" ud
    case $ud in
        [u]* ) scaler $ud; break;;
        [d]* ) scaler $ud; break;;
        * ) echo "Please answer yes or no.";;
    esac
  done
}
machines_join(){
  docker-machine ssh ${1} "docker swarm join \
    --token=${2} \
    --listen-addr $(docker-machine ip ${1}) \
    --advertise-addr $(docker-machine ip ${1}) \
    $(docker-machine ip ${project}m1)"
} 2> /dev/null

# machine creation
create_machines(){
  docker-machine create -d ${mdriver} ${doption} ${eoption} ${1};
  if [ ${1} == ${project}m${nm} ] && [ ! -z "${commands_m}" ] && [ -r "${commands_m}" ]
  then
    echo ${project}m${nm}
    machines_commands ${1} ${commands_m}
  elif [ ${1} == ${project}w${nw} ] && [ ! -z "${commands_w}" ] && [ -r "${commands_w}" ];
  then
    echo ${project}w${nw}
    machines_commands ${1} ${commands_w}
  fi
}

# Create managers and worker nodes
swarm_build(){
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        echo ${project}m${nm}
        create_machines ${project}m${nm}
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do
        create_machines ${project}w${nw}
    done
} 2> /dev/null

# initialize and bootstrap swarm cluster
swarm_init(){
    # initialize Swarm Manager and tokens
    docker-machine ssh "${project}m1" "docker swarm init \
        --listen-addr $(docker-machine ip ${project}m1) \
            --advertise-addr $(docker-machine ip ${project}m1)"

    worker_token="$(docker-machine ssh ${project}m1 docker swarm \
    join-token worker -q)"

    manager_token="$(docker-machine ssh ${project}m1 docker swarm \
    join-token manager -q)"

    #make other managers join the cluster
    for (( nm=2; nm<=${smanager}; nm++ ))
    do
      machines_join ${project}m$nm ${manager_token}
#      swarm_label ${project}m$nm
    done

    #make workers join the cluster
    for (( nw=1; nw<=${sworker}; nw++ ))
    do
      machines_join ${project}w$nw ${worker_token}
#      swarm_label ${project}w$nw      
    done    
} 2> /dev/null

# add label to swarm nodes 
## WARNING: DO NOT PUT YOUR MANAGERS ONLINE 
swarm_label(){
    swarm_nodes=$(docker-machine ls | grep ${project}w | awk '{print$1}')
    eval "$(docker-machine env ${project}m1)"
        if [ "$(grep -q -w "$1" "$labelsrc")" ]
          then
          if [[ ${1} == ${project}m* ]]
            then
            echo -e "\e[33mWARNING: a label will be added to a manager node"
          fi
          lblkey=$(grep -w "$1" "$labelsrc" | awk -F'=' '{print$1}');
          lblvalue=$(grep -w "$1" "$labelsrc" | awk -F'=' '{print$2}');
          echo "${1} swarm node Label is: ${lblkey}=${lblvalue}";
          docker node update --label-add ${lblkey}=${lblvalue} $1;
          echo " "
        fi
} 2> /dev/null

# start an existing swarm cluster
swarm_start(){
    swarm_nodes=$(docker-machine ls | grep ${project} | awk '{print$1}')
    for i in $swarm_nodes
      do if echo "${i} swarm node is starting :"; docker-machine start $i;echo " "
          then
          echo " "
          echo -e "\033[0;32m ------------"
          echo -e "\033[0;32m ${project} swarm cluster is ready "
          echo -e "\033[0;32m ------------"
         fi
    done
} 2> /dev/null

# start a docker swarm stack if exists
start_stack(){
    if [ -f "${CURRENT_DIR}/${stackfile}" ]
    then
    eval "$(docker-machine env ${project}m1)"
        if docker stack deploy -c "${CURRENT_DIR}/${stackfile}" "${project}"
        then
        echo " "
        echo -e "\033[0;32m ------------"
        echo -e "\033[0;32m ${project} stack is ready "
        echo -e "\033[0;32m ------------"
        fi
    fi
}

# start either a CLI or a webui depending of user choice
# cli start dry
# webui start swarmpit
swarm_manage(){
  while true; do
    read -r -p "choose between : cli(c) or webui(w) management tool ?" cw
    case $cw in
        [Cc]* ) dry_manager; break;;
        [Ww]* ) portainer_manager; break;;
        * ) echo "Please choose betwenn cli(c) or webui(w) ";;
    esac
done
}

dry_manager(){
DCERT=$(docker-machine env swarm1m1 | grep CERT | awk '{print$2}')
DHOST=$(docker-machine env swarm1m1 | grep HOST | awk '{print$2}')
DRY_CERT=$( echo ${DCERT} | awk -F'=' '{print$2}')
docker run -it -e ${DHOST} -e ${DCERT} -v ${DRY_CERT}:${DRY_CERT} moncho/dry sh
}

portainer_manager(){
docker run -d -p 9000:9000 portainer/portainer -H tcp://"$(docker-machine ip ${project}m1)":2376
xdg-open http://localhost:9000
}
# stop all swarm nodes nodes
swarm_halt(){
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        docker-machine stop "${project}m${nm}";
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do  
        if docker-machine stop "${project}w${nw}";
          then
            echo " "
            echo -e "\033[0;32m ------------"
            echo -e "\033[0;32m ${project} swarm cluster is halted "
            echo -e "\033[0;32m ------------"
        fi
    done
} 2> /dev/null

menu_delete(){
  while true; do
    read -r -p "Do you REALLY wish to delete ${project} nodes ?" yn
    case $yn in
        [Yy]* ) swarm_delete; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
}

# stop and delete all swarm nodes
swarm_delete(){
    swarm_halt
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        docker-machine rm "${project}m${nm}" -f;
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do
        if docker-machine rm "${project}w${nw}" -f;
          then
            echo " "
            echo -e "\033[0;32m ------------"
            echo -e "\033[0;32m ${project} swarm cluster has been deleted "
            echo -e "\033[0;32m ------------"
        fi
   done
} 2> /dev/null

# list all existing swarm nodes in all configuration files
swarm_list(){
    project_list=$(grep -h "project=" ./*.conf | awk -F'=' '{print$2}')
    for i in ${project_list}
      do echo "${i} swarm nodes:"; docker-machine ls | grep "${i}";echo " "
    done

} 2> /dev/null
# Load and check configuration settings
main() {

  if [ $# -eq 1 ] && [ "${1}" = "-h" ]
    then usage;
  fi


  if [ "${1}" == "-c" ]
  then
      if [ -s "${CURRENT_DIR}/${2}" ] && [ -r "${CURRENT_DIR}/${2}" ]
      then
      cfg_file="${CURRENT_DIR}/${2}"
      source "${cfg_file}"
      else
      echo "your configuration file is missing or is empty"
      exit 1
      fi
      if [ "${1}" != "-c" ] && [ -s ${cfg_file} ] && [ -r ${cfg_file} ]
      then
          source "${cfg_file}"
      fi
  else
       source "${cfg_file}"
  fi

  if [[ "${mdriver}" != "digitalocean" ]]
  then
    if [ -n "${mimage}" ]
    then
    doption="--virtualbox-boot2docker-url=${mimage}"
    else
    doption=
    fi
  else
    mdriver="digitalocean"
    if [ -z "${dotoken}" ]
    then
       echo "you must specify a Digital Ocean token in you ${cfg_file} file"
       exit 1
    else
       doption="--digitalocean-access-token=${dotoken}"
    fi
  fi

  param=${!#}
    case "${param}" in
        init)
            swarm_build
            swarm_init
            start_stack
            ;;
        start)
            swarm_start
            start_stack
            ;;
        stop)
            swarm_halt
            ;;
        rm)
            menu_delete
            ;;
        list)
            swarm_list
            ;;
        scale)
            menu_scale
            ;;
        manage)
            swarm_manage
            ;;
        *)
            usage
            ;;
    esac
}

# ----  MAIN  --------------------------------------------------------------- #
main "$@"
# --------------------------------------------------------------------------- #
