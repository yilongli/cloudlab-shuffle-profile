#! /bin/bash

RC_HOSTS_FILE=$1

while read HOST; do
    HOST_PUBLIC_IP=`geni-get manifest | grep $HOST | egrep -o "ip address=.*" | cut -d'"' -f2`
    echo "$HOST $HOST_PUBLIC_IP"
done < $RC_HOSTS_FILE

