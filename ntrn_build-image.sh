#!/usr/bin/env bash

set -e
PATH_DIR_SELF=$(dirname -- "$( readlink -f -- "$0"; )")

source ./auto/helper-logic
source ./ntrn/helper

# Clear the screen first
clear

ISO_FILE_PATH=${1:-''}
BUILD_FLAVOR=${2:-''}
EXTRA_PACKAGES="${@:3}"

if [ -z "$ISO_FILE_PATH" ]; then
  consoleMsg "danger" "ISO FILE argument needed. Usage: ./ntrn_build-image.sh ISO_FILE_PATH BUILD_FLAVOR EXTRA_PACKAGE_1 EXTRA_PACKAGE_2 EXTRA_PACKAGE_3 ..."
  exit 1
elif [ ! -f "$ISO_FILE_PATH" ]; then
  consoleMsg "danger" "ISO FILE does not exist: $ISO_FILE_PATH"
  exit 1
fi

ISO_FILE_PATH=$(readlink -f -- "$ISO_FILE_PATH")
ISO_FILE_NAME=$(basename "$ISO_FILE_PATH")

if [ -z "$BUILD_FLAVOR" ]; then
  consoleMsg "danger" "BUILD FLAVOR argument needed. Usage: ./ntrn_build-image.sh ISO_FILE_PATH BUILD_FLAVOR EXTRA_PACKAGE_1 EXTRA_PACKAGE_2 EXTRA_PACKAGE_3 ..."
  exit 1
fi

echo "ISO_FILE_PATH: $ISO_FILE_PATH -- ISO_FILE_NAME: $ISO_FILE_NAME -- Extra Packages: $(echo "$EXTRA_PACKAGES" | jq -Rc 'split(" ")')"

# Ensure we are running as root
EnsureRoot

# Ensure stage 8 is complete
EnsureStageIsComplete 8

if ([ "$BRANCH" != "equuleus" ] && [ "$BRANCH" != "sagitta" ]); then
  >&2 echo -e "${RED}Invalid branch${NOCOLOR}"
  exit 1
fi

echo "Cloning the VyOS build repository..."
git clone -q https://github.com/dd010101/vyos-build > /dev/null
pushd vyos-build > /dev/null

echo "Checking out the $BRANCH branch..."
git checkout "$BRANCH" > /dev/null

popd > /dev/null

consoleMsg "info" "Ensuring directory exists: vyos-build/data/build-flavors"
mkdir -p vyos-build/data/build-flavors

consoleMsg "info" "Setting build flavor toml file."
echo "image_format = \"$BUILD_FLAVOR\"" > "vyos-build/data/build-flavors/$BUILD_FLAVOR.toml"

if [ ! -z "$EXTRA_PACKAGES" ]; then
  PACKAGES_JSON_ARR=$(echo "$EXTRA_PACKAGES" | jq -Rc 'split(" ")')
  echo "packages = $PACKAGES_JSON_ARR" >> "vyos-build/data/build-flavors/$BUILD_FLAVOR.toml"
fi

echo "Building the Image..."
if [ "$BRANCH" == "equuleus" ]; then
  consoleMsg "danger" "$BRANCH image build has not implemented yet."
  exit 1
  # function DockerBuild {
  #   docker run --rm --privileged -v ./vyos-build/:/vyos -v "/tmp/apt.gpg.key:/opt/apt.gpg.key" -w /vyos \
  #     --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  #     -e GOSU_UID=$(id -u) -e GOSU_GID=$(id -g) vyos/vyos-build:equuleus \
  #     sudo ./configure \
  #     --architecture amd64 \
  #     --build-by "$1" \
  #     --build-type release \
  #     --build-comment "$4" \
  #     --version "$2" \
  #     --vyos-mirror http://172.17.17.17/equuleus \
  #     --debian-elts-mirror http://172.17.17.17:3142/deb.freexian.com/extended-lts \
  #     --custom-apt-key /opt/apt.gpg.key \
  #     --custom-package "$3"

  #   docker run --rm --privileged --name="vyos-build" -v ./vyos-build/:/vyos -v "/tmp/apt.gpg.key:/opt/apt.gpg.key" -w /vyos --sysctl net.ipv6.conf.lo.disable_ipv6=0 -e GOSU_UID=$(id -u) -e GOSU_GID=$(id -g) -w /vyos vyos/vyos-build:equuleus \
  #     sudo make iso
  # }
elif [ "$BRANCH" == "sagitta" ]; then
  function DockerBuild {
    docker run --rm --privileged --name="vyos-build" \
      -v ./vyos-build/:/vyos -v "$ISO_FILE_PATH:/tmp/$ISO_FILE_NAME" -w /vyos \
      --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
      -e GOSU_UID=$(id -u) -e GOSU_GID=$(id -g) vyos/vyos-build:sagitta \
      sudo --preserve-env ./build-vyos-image \
      --reuse-iso "/tmp/$ISO_FILE_NAME" \
      "$BUILD_FLAVOR"
  }
else
  >&2 echo -e "${RED}Invalid branch${NOCOLOR}"
  exit 1
fi

(
  FilterStderr "( $dockerBuild )" "(useradd warning)"
  exit $?
)

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE != 0 ]; then
  >&2 echo -e "${RED}IMAGE build failed${NOCOLOR}"
  exit 1
fi
