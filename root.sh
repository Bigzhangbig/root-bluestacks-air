#!/bin/bash

BLUESTACKS=/Applications/BlueStacks.app
ADB_PORT=5555
ARCH=arm64-v8a
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
MAGISK_BIN_DIR=$BASE_DIR/magisk-bin
INITRD_PATH=$BLUESTACKS/Contents/img/initrd_hvf.img
INITRD_INPUT=$INITRD_PATH
INITRD_BACKUP=$INITRD_PATH.bak
INITRD_OUTPUT=$INITRD_PATH
INPLACE=1
MAGISK_APK=$BASE_DIR/magisk.apk
STAGE2_INJECT_BEGIN="# BST-AIR-ROOT:MAGISK_RC_INJECT_BEGIN"
STAGE2_INJECT_END="# BST-AIR-ROOT:MAGISK_RC_INJECT_END"

abspath() {
  if  [[ $1 == /* ]]; then
    echo $1
  else
    echo $(pwd)/$1
  fi
}

die() {
  echo "[!] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

validate_initrd() {
  [[ -f "$INITRD_INPUT" ]] || die "initrd not found: $INITRD_INPUT"
  gzip -t "$INITRD_INPUT" >/dev/null 2>&1 || die "initrd is not a valid gzip file: $INITRD_INPUT"
  gzip -dc "$INITRD_INPUT" | cpio -it 2>/dev/null | grep -qx "boot/stage2.sh" || die "initrd does not contain boot/stage2.sh"
}

while getopts "h?i:b:o:" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $0 [-i initrd_input_path] [-o initrd_output_path] [-b backup_dir]"
        exit 0
        ;;
    i)  INITRD_INPUT=$( abspath ${OPTARG} )
        INPLACE=0
        ;;
    o)  INITRD_OUTPUT=$( abspath ${OPTARG} )
        mkdir -p "$( dirname "$INITRD_OUTPUT" )"
        INPLACE=0
        ;;
    b)  BACKUP_DIR=$( abspath ${OPTARG} )
        mkdir -p "$BACKUP_DIR"
        INITRD_BACKUP=$BACKUP_DIR/initrd_hvf.img
        ;;
    esac
done

if [ -d "$BLUESTACKS" ]; then
  PLIST_FILE=$BLUESTACKS/Contents/Info.plist
  BS_VERSION=$(defaults read $PLIST_FILE CFBundleVersion 2>/dev/null)
  echo "[*] Found BlueStacks Air version $BS_VERSION"
  echo ''
else
  if [ $INPLACE -eq 1 ]; then
    echo "[!] BlueStacks not found"
    exit 1
  fi
fi

require_cmd gzip
require_cmd cpio
require_cmd unzip
require_cmd sed
require_cmd dirname
require_cmd mkdir
require_cmd cp
require_cmd chmod
require_cmd cat
require_cmd find
require_cmd grep
require_cmd awk

if [ $INPLACE -eq 1 ]; then
  require_cmd defaults
  require_cmd pkill
  require_cmd open
fi

[[ -f "$MAGISK_APK" ]] || die "Missing magisk.apk in project folder (expected: $MAGISK_APK)"

validate_initrd

echo '=================================================='
echo '**                                              **'
echo '**        BlueStacks Air Magisk Installer       **'
echo '**                                              **'
echo '=================================================='
echo ''

if [ $INPLACE -eq 1 ]; then
  pkill -x BlueStacks
  echo 'Checklist:'
  echo '* You have started BlueStacks for the first time.'
  echo '* BlueStacks is closed before proceeding.'
  echo ''
fi

read -p "Continue? (y/n): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0

echo '[*] Preparing magisk'
[[ -d magisk ]] && rm -rf magisk
unzip -oq "$MAGISK_APK" -d magisk
[[ -d magisk/lib/$ARCH ]] || die "Unsupported architecture in magisk.apk (expected libs under: magisk/lib/$ARCH)"

[[ -d $MAGISK_BIN_DIR ]] && rm -rf $MAGISK_BIN_DIR
mkdir "$MAGISK_BIN_DIR"

BIN_NAMES=("magisk64" "magiskinit" "magiskpolicy")
for BIN_NAME in ${BIN_NAMES[@]}; do
  SRC=magisk/lib/$ARCH/lib$BIN_NAME.so
  [[ -f $SRC ]] && cp "$SRC" "$MAGISK_BIN_DIR/$BIN_NAME"
done
cp magisk/assets/stub.apk "$MAGISK_BIN_DIR/stub.apk"

rm -rf magisk

echo "[*] Backing up initrd to $INITRD_BACKUP"
[[ "$INITRD_BACKUP" != "$INITRD_INPUT" ]] || die "Backup path equals input path: $INITRD_BACKUP"
[[ ! -f "$INITRD_BACKUP" ]] && cp "$INITRD_INPUT" "$INITRD_BACKUP"

[[ ! -d build ]] && mkdir build
cd build

echo '[*] Patching initrd'
[[ -d initrd ]] && rm -rf initrd
mkdir initrd
cd initrd
cat "$INITRD_BACKUP" | cpio -id
cp -r "$MAGISK_BIN_DIR" boot/magisk
chmod 700 boot/magisk/*
cp "$BASE_DIR/magisk.rc" boot/magisk.rc
if [ -f $MAGISK_BIN_DIR/magisk32 ]; then
  sed -i '' -e 's/magisk64/magisk32/g' boot/magisk.rc
fi

if grep -qF "$STAGE2_INJECT_BEGIN" boot/stage2.sh || grep -qF "cat /boot/magisk.rc >> /init.bst.rc" boot/stage2.sh; then
  echo '[*] stage2.sh already patched (skipping injection)'
else
  echo '[*] Injecting magisk.rc into stage2.sh'
  awk '
    BEGIN { removed=0 }
    $0 ~ /^[[:space:]]*exec[[:space:]]+\/init[[:space:]]*$/ {
      if (!removed) { removed=1; next }
    }
    { print }
    END { if (!removed) exit 2 }
  ' boot/stage2.sh > boot/stage2.sh.tmp || die "Cannot locate 'exec /init' in boot/stage2.sh"
  mv boot/stage2.sh.tmp boot/stage2.sh
  cat << EOF >> boot/stage2.sh
$STAGE2_INJECT_BEGIN
log_echo "Installing magisk.rc"
cat /boot/magisk.rc >> /init.bst.rc
die_if_error "Cannot install magisk.rc"

exec /init
$STAGE2_INJECT_END
EOF
fi

echo "[*] Repacking initrd to $INITRD_OUTPUT"
find . | cpio -H newc -o | gzip > $INITRD_OUTPUT

cd $BASE_DIR

# Cleanup
rm -rf build
rm -rf $MAGISK_BIN_DIR

if [ $INPLACE -eq 1 ]; then
  echo '[*] Starting BlueStacks'
  open -n $BLUESTACKS
  echo '[*] Done'
  echo ''
  echo '=================================================='
  echo ''
  echo 'Next steps:'
  echo '* Install magisk.apk'
  echo '* Open Kitsune Mask app and proceed with additional setup'
  echo '* Quit BlueStacks'
else
  echo '[*] Done'
  echo ''
  echo '=================================================='
  echo ''
  echo 'Next steps:'
  echo "* Copy $INITRD_OUTPUT to $INITRD_PATH"
  echo '* Open BlueStacks'
  echo '* Install magisk.apk'
  echo '* Open Kitsune Mask app and proceed with additional setup'
  echo '* Quit BlueStacks'
fi
