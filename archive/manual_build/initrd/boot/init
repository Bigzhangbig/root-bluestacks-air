#!/boot/bin/sh

PATH=/boot/sbin:/boot/bin
export PATH

/boot/bin/busybox mknod /dev/kmsg c 1 11

log_echo()
{
	echo "$@" > /dev/kmsg
}

log_echo Starting BlueStacks Userland
exec >/dev/kmsg 2>/dev/kmsg
umask 022

die_if_error()
{
	if [ $? -ne 0 ]; then
		log_echo "$@"
		exit 1
	fi
}

#
# Ask busybox to populate /boot/bin and /boot/sbin.
#

/boot/bin/busybox --install -s /boot/bin

#
# Mount /proc and /sys.
#

mkdir /proc
mount -t proc proc /proc
die_if_error "Cannot mount /proc"

mkdir /sys
mount -t sysfs sysfs /sys
die_if_error "Cannot mount /sys"

#
# Now that /sys is mounted, we can populate /dev.
#

mdev -s

#
WINDOWSGATEWAY="10.0.2.2"
echo "WindowsGateway : $WINDOWSGATEWAY"
export WINDOWSGATEWAY

# Load our uHD kernel modules.
#

grep SHELL_BEFORE_KMODS= /proc/cmdline > /dev/null
if [ $? -eq 0 ]; then
	log_echo Starting debug shell before kernel modules
	log_echo Please exit the shell to continue the boot process
	env HAS_CTTY=Yes setsid cttyhack /boot/bin/sh
fi

load_module()
{
	log_echo "Loading module $1"
	insmod $1
	die_if_error "Cannot load module $1"
}

# insmod bst drivers

load_module /boot/bstmods/bstpgaipc.ko
load_module /boot/bstmods/bstgmd.ko
load_module /boot/bstmods/bstvmsg.ko
load_module /boot/bstmods/bstinput.ko
load_module /boot/bstmods/bstaudio.ko
load_module /boot/bstmods/videobuf-core.ko
load_module /boot/bstmods/bstcamera.ko

mdev -s

#
# Mount the appropriate file system for ramdisk.img and system.img.
#

grep SHELL_BEFORE_MOUNTS= /proc/cmdline > /dev/null
if [ $? -eq 0 ]; then
	log_echo Starting debug shell before mounts
	log_echo Please exit the shell to continue the boot process
	env HAS_CTTY=Yes setsid cttyhack /boot/bin/sh
fi

mkdir /boot/android

log_echo "Mounting Android root file system /dev/vda1"
mount -o ro /dev/vda1 /boot/android
die_if_error "Cannot mount Android root file system"

#
# Prepare our root file system.
#

cd /

#
# Use the new /proc/cmdline to populate the environment.
#
populate_environment()
{
	while [ $# -ne 0 ]; do
	    # Making sure that if name contains ".", we don't export it in environment
        case "$1" in
            *.*=*)
                log_echo "not setting $1 as this contains '.' in name"
                ;;
            *)
                log_echo "setting env $1"
                export $1
                ;;
        esac
		shift
	done
}

log_echo "Reading cmdline"
log_echo `cat /proc/cmdline`

log_echo "Setting cmdline as env"
populate_environment `cat /proc/cmdline`

log_echo "Extracting ramdisk.img"
zcat /boot/android/android/ramdisk.img | cpio -id
die_if_error "Cannot extract ramdisk.img"

log_echo "Mounting system directory"
mkdir /system
mount -o loop /boot/android/android/system /system
die_if_error "Cannot mount system directory"

ln -s /boot/android/android/system/apex/com.android.runtime \
    /apex/com.android.runtime

log_echo "Mount /data"
mount -t ext4 -o rw /dev/vdb1 /data

mount -t tmpfs tmpfs cache

export PATH=/boot:$PATH

log_echo "Checking for debug shell"
grep SHELL_BEFORE_STAGE2= /proc/cmdline > /dev/null
if [ $? -eq 0 ]; then
	log_echo Starting debug shell before stage 2
	log_echo Please exit the shell to continue the boot process
	env HAS_CTTY=Yes setsid cttyhack /boot/bin/sh
fi

PATH=/system/bin:/system/xbin:/sbin

#bstreport timeline "first_stage_init_completed"

log_echo "Running bstsetconf script"
source /boot/bstsetconf.sh

populate_bst_conf
generate_android_ids

if [ -z "$BST_MEM_PCR_PCD_UNUSED" ]; then
    if [ -e /proc/sys/vm/pcr_enabled -a ! -z "$BST_MEM_PCR_ENABLED" ]; then
        echo $BST_MEM_PCR_ENABLED > /proc/sys/vm/pcr_enabled
    else
        log_echo "bst.mem_pcr_enabled property not found"
    fi
    if [ -e /proc/sys/vm/pcr_pclimit -a ! -z "$BST_MEM_PCR_PCLIMIT" ]; then
        echo $BST_MEM_PCR_PCLIMIT > /proc/sys/vm/pcr_pclimit
    else
        log_echo "bst.mem_pcr_pclimit property not found"
    fi
else
    log_echo "bst.mem_pcr_pcd_unused is set, skipping pcd pcr configuration"
fi

log_echo "Running stage2 script"
exec sh /boot/stage2.sh
