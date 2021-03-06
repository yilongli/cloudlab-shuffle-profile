#!/bin/bash

# Configurations that need to be (re)done after each reboot

# https://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

# According to RHEL 7 Performance Tuning Guide, the latency-performance
# profile sets CPU governor to performance and locked the CPU to the low
# C states (by PM QoS)".
tuned-adm profile latency-performance
echo "boot-setup.sh: tuned-adm activates latency-performance profile"

# Setup password-less ssh between nodes
USERS="root `ls /users`"
for user in $USERS; do
    if [ "$user" = "root" ]; then
        ssh_dir=/root/.ssh
    else
        ssh_dir=/users/$user/.ssh
    fi
    pushd $ssh_dir
    geni-get key > id_rsa
    chmod 600 id_rsa
    chown $user: id_rsa
    ssh-keygen -y -f id_rsa > id_rsa.pub
    cp id_rsa.pub authorized_keys2
    chmod 644 authorized_keys2
    cat >>config <<EOL
    Host *
         StrictHostKeyChecking no
EOL
    chmod 644 config
    popd
done
echo "boot-setup.sh: setup passwordless ssh between nodes"
