#!/usr/bin/env bash

set -e
PATH_DIR_SELF=$(dirname -- "$( readlink -f -- "$0"; )")

source ./ntrn/helper

wget https://vyos.tnyzeq.icu/apt/apt.gpg.key -O /tmp/apt.gpg.key

rm -rf vyos-build/
git clone https://github.com/dd010101/vyos-build.git
git -C vyos-build/ checkout sagitta

PATH_DIR_VYOS_BUILD="$PATH_DIR_SELF/vyos-build"

DEF_PATH_ISO="/tmp/vyos.iso"
DEF_BUILD_FLAVOR="qcow2"
DEF_CUSTOM_PACKAGE="qemu-guest-agent"

read -p "Enter ISO Path [$DEF_PATH_ISO]: " PATH_ISO
PATH_ISO=${PATH_ISO:-$DEF_PATH_ISO}
PATH_ISO=$(readlink -f -- "$PATH_ISO")

if [ ! -f "$PATH_ISO" ]; then
  consoleMsg "danger" "ISO FILE does not exist: $PATH_ISO"
  exit 1
fi

NAME_ISO=$(basename "$PATH_ISO")

read -p "Enter build flavor [$DEF_BUILD_TYPE]: " BUILD_FLAVOR
BUILD_FLAVOR=${BUILD_FLAVOR:-$DEF_BUILD_FLAVOR}

read -p "Enter custom packages [$DEF_CUSTOM_PACKAGE]: " CUSTOM_PACKAGE
CUSTOM_PACKAGE=${CUSTOM_PACKAGE:-$DEF_CUSTOM_PACKAGE}

consoleMsg "info" "PATH_ISO: $PATH_ISO"
consoleMsg "info" "NAME_ISO: $NAME_ISO"
consoleMsg "info" "BUILD_FLAVOR: $BUILD_FLAVOR"
consoleMsg "info" "CUSTOM_PACKAGE: $CUSTOM_PACKAGE"

read -p "Continue? " -n 1 -r
echo 
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

consoleMsg "info" "Setting build flavor toml file."
flavorToml="$PATH_DIR_VYOS_BUILD/data/build-flavors/$BUILD_FLAVOR.toml"
echo "image_format = \"$BUILD_FLAVOR\"" > "$flavorToml"

if [ ! -z "$CUSTOM_PACKAGE" ]; then
  PACKAGES_JSON_ARR=$(echo "$CUSTOM_PACKAGE" | jq -Rc 'split(" ")')
  echo "packages = $PACKAGES_JSON_ARR" >> "$flavorToml"
fi

docker pull vyos/vyos-build:sagitta
docker run --rm --privileged --name="vyos-build" -v ./vyos-build/:/vyos -e GOSU_UID=$(id -u) -e GOSU_GID=$(id -g) \
    --sysctl net.ipv6.conf.lo.disable_ipv6=0 -v "/tmp/apt.gpg.key:/opt/apt.gpg.key" -w /vyos vyos/vyos-build:sagitta \
    sudo --preserve-env ./build-vyos-image iso \
        --architecture amd64 \
        --build-by "$BUILD_BY" \
        --build-type "$BUILD_TYPE" \
        --debian-mirror http://deb.debian.org/debian/ \
        --version "$BUILD_VERSION" \
        --vyos-mirror "https://vyos.tnyzeq.icu/apt/sagitta" \
        --custom-apt-key /opt/apt.gpg.key \
        --custom-package "$CUSTOM_PACKAGE"

if [ -f vyos-build/build/live-image-amd64.hybrid.iso ]; then
    iso="vyos-$BUILD_VERSION-iso-amd64.iso"
    mv vyos-build/build/live-image-amd64.hybrid.iso "$iso"
    echo "Build successful - $iso"
else
    >&2 echo "ERROR: ISO not found, something is wrong - see previous messages for what failed"
    exit 1
fi