#!/bin/sh
log_echo()
{
    echo "$@" > /dev/kmsg
}
exec >/dev/kmsg 2>/dev/kmsg
umask 022

die()
{
	log_echo "<2>ERROR: $@"
	exit 1
}

warn_if_error()
{
	if [ $? -ne 0 ]; then
		log_echo "<3>WARNING: $@"
	fi
}

die_if_error()
{
	if [ $? -ne 0 ]; then
		die "$@"
	fi
}

#
# Basic mounts and devices.
#

log_echo "Mounting file systems"
mkdir -p /mnt/tmp

source /boot/bstsetup.env
source /boot/4-dpi

prepare_bst_filesystems
enable_swapspace
setup_dpi
set_propfile_permissions


mount -t debugfs debugfs /sys/kernel/debug 2> /dev/null
die_if_error "Cannot mount /sys/kernel/debug"

#mkdir -p /mnt/Pictures
#mount -t bstfolder Pictures /mnt/Pictures
#die_if_error "Cannot mount /mnt/Pictures"

#
# Create the Android logger device nodes.
#

mkdir /dev/log

for i in main events system radio; do
    if [ -f /sys/devices/virtual/misc/log_$i/dev ]; then
        local nums=`cat /sys/devices/virtual/misc/log_$i/dev | tr ':' ' '`
        mknod /dev/log/$i c $nums
    fi
done

#
# Bring up the network.
#

log_echo "Configuring network"

echo 1 > /proc/sys/net/ipv6/conf/eth0/disable_ipv6
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up

route add default gw $WINDOWSGATEWAY dev eth0
warn_if_error "Cannot add default route"

ifconfig lo up
# This is done to make sure that if any VPN service is running on Android
# our local traffic to windows is not intercepted by VPN server.
ip route add $WINDOWSGATEWAY dev eth0 table local
warn_if_error "Cannot add local route"

echo 'nameserver 10.0.2.3' > /boot/resolv.conf

warn_if_error "Cannot configure nameserver"

#
# Print a shiny welcome banner and drop the user to a shell if he/she
# has asked for one.
#

log_echo "Welcome to BlueStacks Android"
uname -a

grep SHELL_BEFORE_INIT= /proc/cmdline > /dev/null
if [ $? -eq 0 ]; then
	log_echo Starting debug shell before init
	log_echo Please exit the shell to continue the boot process
	env HAS_CTTY=Yes setsid /boot/bin/cttyhack /boot/bin/ash
fi

log_echo "Starting Android"

#bstreport timeline "second_stage_init_completed"

# BST-AIR-ROOT:MAGISK_RC_INJECT_BEGIN
log_echo "Installing magisk.rc"
cat /boot/magisk.rc >> /init.bst.rc
die_if_error "Cannot install magisk.rc"

exec /init
# BST-AIR-ROOT:MAGISK_RC_INJECT_END
