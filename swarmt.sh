#!/bin/bash
# shellcheck disable=SC1090
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
      docker-machine ssh ${1} "$line"
    done < ${2}
  fi
} 2> /dev/null

machines_join(){
  docker-machine ssh ${1} "docker swarm join \
    --token=${2} \
    --listen-addr $(docker-machine ip ${1}) \
    --advertise-addr $(docker-machine ip ${1}) \
    $(docker-machine ip ${project}m1)"
} 2> /dev/null

# Create managers and worker nodes
create_machines(){
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        docker-machine create -d ${mdriver} ${doption} ${eoption} ${project}m${nm};
        machines_commands ${project}m${nm} ${commands_m}
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do
        docker-machine create -d ${mdriver} ${doption} ${eoption} ${project}w${nw};
        machines_commands ${project}w${nw} ${commands_w}
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

#    export worker_token manager_token

    #make other managers join the cluster
    for (( nm=2; nm<=${smanager}; nm++ ))
    do
      machines_join ${project}m$nm ${manager_token}
    done

    #make workers join the cluster
    for (( nw=1; nw<=${sworker}; nw++ ))
    do
      machines_join ${project}w$nw ${worker_token}
    done

    if [ $? -eq 0 ]
    then
    echo " "
    echo -e "\033[0;32m ------------"
    echo -e "\033[0;32m ${project} swarm cluster is up and running "
    echo -e "\033[0;32m ------------"
    else
    echo " "
    echo -e "\033[0;31m ------------"
    echo -e "\033[0;31m something wen't wrong!"
    echo -e "\033[0;31m ------------"
    exit 1
    fi
} 2> /dev/null

# start an existing swarm cluster
swarm_start(){
    swarm_nodes=$(docker-machine ls | grep ${project} | awk '{print$1}')
    for i in $swarm_nodes
      do echo "${i} swarm node is starting :"; docker-machine start $i;echo " "
    done

    if [ "${?}" -eq 0 ]
    then
    echo " "
    echo -e "\033[0;32m ------------"
    echo -e "\033[0;32m ${project} swarm cluster is ready "
    echo -e "\033[0;32m ------------"
    fi
} 2> /dev/null

# start a docker swarm stack if exists
start_stack(){
    if [ -f "${CURRENT_DIR}/${stackfile}" ]
    then
    eval "$(docker-machine env ${project}m1)"
    docker stack deploy -c "${CURRENT_DIR}/${stackfile}" "${project}"
        if [ $? -eq 0 ]
        then
        echo " "
        echo -e "\033[0;32m ------------"
        echo -e "\033[0;32m ${project} stack is ready "
        echo -e "\033[0;32m ------------"
        fi
    fi
} 2> /dev/null

# stop all swarm nodes nodes
swarm_halt(){
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        docker-machine stop "${project}m${nm}";
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do
        docker-machine stop "${project}w${nw}";
    done

    if [ "${?}" -eq 0 ]
    then
    echo " "
    echo -e "\033[0;32m ------------"
    echo -e "\033[0;32m ${project} swarm cluster is halted "
    echo -e "\033[0;32m ------------"
    fi

} 2> /dev/null

swarm_delete_confirm(){
  while true; do
    read -p "Do you REALLY wish to delete ${project} nodes ?" yn
    case $yn in
        [Yy]* ) swarm_delete; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
} 2> /dev/null
# stop and delete all swarm nodes
swarm_delete(){
    swarm_halt
    for (( nm=1; nm<="${smanager}"; nm++ ))
      do
        docker-machine rm "${project}m${nm}" -f;
    done
    for (( nw=1; nw<="${sworker}"; nw++ ))
      do
        docker-machine rm "${project}w${nw}" -f;
    done

    if [ "${?}" -eq 0 ]
    then
    echo " "
    echo -e "\033[0;32m ------------"
    echo -e "\033[0;32m ${project} swarm cluster has been deleted "
    echo -e "\033[0;32m ------------"
   fi
} 2> /dev/null

# list all existing swarm nodes in all configuration files
swarm_list(){
    project_list=$(grep -h "project" *.conf | awk -F'=' '{print$2}')
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
            create_machines
            swarm_init
            start_stack
            ;;
        start)
            swarm_start
            ;;
        stop)
            swarm_halt
            ;;
        rm)
            swarm_delete_confirm
            ;;
        list)
            swarm_list
            ;;
        command)
            machines_commands swarm1m1 worker.conf
            ;;
        *)
            usage
            ;;
    esac
}

# ----  MAIN  --------------------------------------------------------------- #
main "$@"
# --------------------------------------------------------------------------- #
