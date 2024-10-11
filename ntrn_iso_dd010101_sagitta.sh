#!/usr/bin/env bash

set -e
PATH_DIR_SELF=$(dirname -- "$( readlink -f -- "$0"; )")

source ./ntrn/helper

wget https://vyos.tnyzeq.icu/apt/apt.gpg.key -O /tmp/apt.gpg.key

rm -rf vyos-build/
git clone https://github.com/dd010101/vyos-build.git
git -C vyos-build/ checkout sagitta

PATH_DIR_VYOS_BUILD="$PATH_DIR_SELF/vyos-build"

DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SAFE=${DATE//-/}
DATE_SAFE=${DATE_SAFE//:/}

DEF_BUILD_NAME="ntrnROS"
DEF_BUILD_TYPE="release"
DEF_BUILD_VERSION="1.4.x-$DATE_SAFE"
DEF_BUILD_BY="noc@blrm.net"
DEF_CUSTOM_PACKAGE="vyos-1x-smoketest cloud-init"

read -p "Enter build name [$DEF_BUILD_NAME]: " BUILD_NAME
BUILD_NAME=${BUILD_NAME:-$DEF_BUILD_NAME}

read -p "Enter build type [$DEF_BUILD_TYPE]: " BUILD_TYPE
BUILD_TYPE=${BUILD_TYPE:-$DEF_BUILD_TYPE}

read -p "Enter version [$DEF_BUILD_VERSION]: " BUILD_VERSION
BUILD_VERSION=${BUILD_VERSION:-$DEF_BUILD_VERSION}

read -p "Enter build by [$DEF_BUILD_BY]: " BUILD_BY
BUILD_BY=${BUILD_BY:-$DEF_BUILD_BY}

read -p "Enter custom packages [$DEF_CUSTOM_PACKAGE]: " CUSTOM_PACKAGE
CUSTOM_PACKAGE=${CUSTOM_PACKAGE:-$DEF_CUSTOM_PACKAGE}

consoleMsg "info" "Removing branding..."

defaultSplash="$PATH_DIR_VYOS_BUILD/data/live-build-config/includes.binary/isolinux/splash.png"
if [ -f "$defaultSplash" ]; then
    consoleMsg "info" "Removing existing splash image."
    rm -f "$defaultSplash"
fi

${PATH_DIR_SELF}/ntrn/splash.sh \
--src "$PATH_DIR_SELF/ntrn/splash.png" \
--dst "$defaultSplash" \
--text "v1.4.x $BUILD_TYPE $DATE" \
--font-size 18 \
--text-color white \
--x-align right \
--y-align bottom \
--x-margin 20 \
--y-margin 30

consoleMsg "success" "$BUILD_NAME splash image generated."

sed -i "s/VyOS/$BUILD_NAME/" "$PATH_DIR_VYOS_BUILD/data/live-build-config/includes.binary/isolinux/menu.cfg"

defaultToml="$PATH_DIR_VYOS_BUILD/data/defaults.toml"
if [ -f "$defaultToml" ]; then
    sed -i -E 's/website_url =.*/website_url = "localhost"/' "$defaultToml"
    sed -i -E 's/support_url =.*/support_url = "There is no official support."/' "$defaultToml"
    sed -i -E 's/bugtracker_url =.*/bugtracker_url = "DO NOT report bugs to VyOS!"/' "$defaultToml"
    sed -i -E "s/project_news_url =.*/project_news_url = \"This is unofficial $BUILD_NAME build.\"/" "$defaultToml"
fi

defaultMotd="$PATH_DIR_VYOS_BUILD/data/live-build-config/includes.chroot/usr/share/vyos/default_motd"
if [ -f "$defaultMotd" ]; then
    sed -i "s/VyOS/$BUILD_NAME/" "$defaultMotd"
    sed -i -E "s/Check out project news at.*/This is unofficial $BUILD_NAME build./" "$defaultMotd"
    sed -i -E 's/and feel free to report bugs at.*/DO NOT report bugs to VyOS!/' "$defaultMotd"
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