#!/bin/bash
#
# Generate CloudLab-specific Caladan runtime config file for the local machine.
# Since each machine needs a different config file, a typical way to use this
# script is to run it within clustershell.py.
IFNAME=$1
NCPU=$2
echo "# Caladan runtime config for CloudLab machines"
HOST_IP=`ip -4 addr show $IFNAME | grep -Po 'inet \K[0-9.]*'`
echo "host_addr $HOST_IP"
echo "host_netmask 255.255.255.0"
echo "host_gateway 10.10.1.0"
echo "runtime_kthreads $NCPU"
echo "runtime_guaranteed_kthreads $NCPU"
echo "runtime_spinning_kthreads $NCPU"
