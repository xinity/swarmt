# swarmt
a dead simple tool to manage your local swarm clusters

## Introduction:
Swarmt has been written to offer a simple, extensible and yet powerful tool to manage local swarm clusters built using docker-machine.  

***note:*** as of 0.1 version swarmt support virtualbox, digital ocean is in alpha stage for now *(needs testers)*

## Usage:
clone this repository and launch `swarmt.sh`

```
git clone https://github.com/xinity/swarmt.git
cd swarmt
./swarmt.sh
```

Swarmt is self explained, you should see the default help below:

```
=================================================
 swarmt.sh takes arguments described below: 
    -h    : show this help box 
    init  : create and initialize swarm cluster
    start : start an existing swarm cluster
    list  : list existing nodes 
    stop  : Halt every swarm nodes 
    rm    : delete the swarm cluster 

You can pass a specific configuration file:  
./swarmt.sh -c swarm.conf init 

By default the script will be looking 
for a config file named: swarmt.conf
=================================================
```

Configuration file holds parameters needed to swarmt and should at least contains:  
`project`: name of your projects. you swarm nodes will be named *projectm$n* for managers and *projectw$n* for workers  
`smanager`: number of manager nodes  
`sworker`: number of worker nodes  
`mdriver`: docker-machine you want to use *(virtualbox for now, digital ocean in the next release)*  
`mimage`: docker-machine image you want to use  
`dotoken`: digital-ocean token **alpha stage**  
`stackfile`: docker-compose yml you want to be used to deploy your services  

#### Sample: swarmt.conf  
```
project=myswarmproject
smanager=1
sworker=1
mdriver=virtualbox
mimage=https://releases.rancher.com/os/latest/rancheros.iso
dotoken=
stackfile=docker-compose.yml
```
### Example:  

#### Single swarm cluster

Let's start with a very simple swarm cluster (i.e 1 manager and 2 workers) for a mysql galera cluster.  
edit `swarmt.conf` as below:
```
project=swarmG
smanager=1
sworker=2
mdriver=virtualbox
mimage=https://releases.rancher.com/os/latest/rancheros.iso
dotoken=
stackfile=swarmG.yml
```
In this example, swarmG.yml doesn't exist so `swarmt` won't deploy any container

Time to fire up our swarm cluster:  
`./swarmt.sh init` <=== yes ! that simple!  

Few minutes later, you should have this message:   
`swarmG swarm cluster is up and running`  

Let's see if it really works !  
```
eval $(docker-machine env swarmGm1)
docker node ls
```

Should output:
```
swarGm1     *        virtualbox      Running   tcp://192.168.99.100:2376           v17.05.0-ce   
swarGw1     -        virtualbox      Running   tcp://192.168.99.101:2376           v17.05.0-ce   
swarGw2     -        virtualbox      Running   tcp://192.168.99.102:2376           v17.05.0-ce  
```

Awesome !  

More examples on my blog post: 
