#!/bin/bash
#update repos
apt-get update
#stop all instances
su -l AMP -c "/opt/cubecoders/amp/ampinstmgr -o"
#upgrade all instances as AMP
su -l AMP -c "/opt/cubecoders/amp/ampinstmgr -p"
#start all instances
su -l AMP -c "/opt/cubecoders/amp/ampinstmgr -a"