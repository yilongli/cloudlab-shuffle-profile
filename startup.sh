#!/bin/bash

# Log output of this script to syslog.
# https://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Variables
HOSTNAME=$(hostname -f | cut -d"." -f1)
OS_VER="ubuntu`lsb_release -r | cut -d":" -f2 | xargs`"
MLNX_OFED_VER=5.0-2.1.8.0
MLNX_OFED="MLNX_OFED_LINUX-$MLNX_OFED_VER-$OS_VER-x86_64"
SHARED_HOME="/shome"
USERS="root `ls /users`"
RC_NODE=`hostname --short`

# Test if startup service has run before.
# TODO: why?
if [ -f /local/startup_service_done ]; then
    date >> /local/startup_service_exec_times.txt
    exit 0
fi

# Skip any interactive post-install configuration step:
# https://serverfault.com/q/227190
export DEBIAN_FRONTEND=noninteractive

# Install packages
echo "Installing common utilities"
apt-get update
apt-get -yq install ccache cmake htop mosh vim tmux pdsh tree axel \
        datamash python2 python-is-python2

echo "Installing NFS"
apt-get -yq install nfs-kernel-server nfs-common

echo "Installing performance tools"
kernel_release=`uname -r`
apt-get -yq install linux-tools-common linux-tools-${kernel_release} \
        cpuset msr-tools i7z numactl tuned

echo "Installing Caladan dependencies"
apt-get -yq install libnl-3-dev libnl-route-3-dev libaio-dev uuid-dev \
        libcunit1-dev libnuma-dev

echo "Installing nightly Rust"
curl https://sh.rustup.rs -sSf | sh
rustup default nightly

# Install crontab job to run the following script every time we reboot:
# https://superuser.com/questions/708149/how-to-use-reboot-in-etc-cron-d
echo "@reboot root /local/repository/boot-setup.sh" > /etc/cron.d/boot-setup
/local/repository/boot-setup.sh

# Change user login shell to Bash
for user in `ls /users`; do
    chsh -s `which bash` $user
done

# Fix "rcmd: socket: Permission denied" when using pdsh
echo ssh > /etc/pdsh/rcmd_default

# Download and install Mellanox OFED package
pushd /local
axel -n 8 -q http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_OFED_VER/$MLNX_OFED.tgz
tar xzf $MLNX_OFED.tgz
# m510 and xl170 nodes are equipped with Mellanox Ethernet cards, which can
# be used via either DPDK or the raw mlx4/5 driver.
# Note: option "--upstream-libs --dpdk" is required to compile DPDK later.
# http://doc.dpdk.org/guides/nics/mlx5.html#quick-start-guide-on-ofed-en
$MLNX_OFED/mlnxofedinstall --dpdk --upstream-libs --force --without-fw-update
popd

# Configure 4K 2MB huge pages permanently.
echo "vm.nr_hugepages=4096" >> /etc/sysctl.conf

if [ "$RC_NODE" = "rcnfs" ]; then
    # Setup nfs server following instructions from the links below:
    #   https://vitux.com/install-nfs-server-and-client-on-ubuntu/
    #   https://linuxconfig.org/how-to-configure-a-nfs-file-server-on-ubuntu-18-04-bionic-beaver
    # In `cloudlab-profile.py`, we already asked for a temporary file system
    # mounted at /shome.
    chmod 777 $SHARED_HOME
    echo "$SHARED_HOME *(rw,sync,no_root_squash)" >> /etc/exports

    # Enable nfs server at boot time.
    # https://www.shellhacks.com/ubuntu-centos-enable-disable-service-autostart-linux/
    systemctl enable nfs-kernel-server
    systemctl restart nfs-kernel-server

    # Generate a list of machines (excluding rcnfs) in the cluster
    cd $SHARED_HOME
    > rc-hosts.txt
    let num_rcxx=$(geni-get manifest | grep -o "<node " | wc -l)-1
    for i in $(seq "$num_rcxx")
    do
        rc_host=`printf "rc%02d" $i`
        public_ip=`geni-get manifest | grep $rc_host |  egrep -o "ipv4=.*" | cut -d'"' -f2`
        private_ip=`geni-get manifest | grep $rc_host |  egrep -o "ip address=.*" | cut -d'"' -f2`
        printf "%s %s %s\n" $rc_host $public_ip $private_ip >> rc-hosts.txt
    done
else
    # NFS clients setup: use the publicly-routable IP addresses for both the server
    # and the clients to avoid interference with the experiment.
    rcnfs_ip=`geni-get manifest | grep rcnfs | egrep -o "ipv4=.*" | cut -d'"' -f2`
    mkdir $SHARED_HOME
    echo "$rcnfs_ip:$SHARED_HOME $SHARED_HOME nfs4 rw,sync,hard,intr,addr=`hostname -i` 0 0" >> /etc/fstab

    # Generate the default Caladan config file in the home directory
    ifname=`ifconfig -s | egrep "^en[0-9a-z]*" -o | tail -n 1`
    for ht in {1..8..1}; do
        /local/repository/print_caladan_config.sh $ifname $ht > /users/yilongl/caladan_${ht}HT.config
    done
fi

# Mark the startup service has finished
echo "Startup service finished" > /local/startup_service_done

# Reboot to let the configuration take effects; this task is launched as a
# background process and detached from the current process.
if [ "$RC_NODE" != "rcnfs" ]; then
    nohup sleep 10s && reboot &
fi
