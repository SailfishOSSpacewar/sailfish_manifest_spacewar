#!/bin/bash

set -euo pipefail

log() { echo -e "\n[+] $1\n"; }
fail() { echo -e "\n[!] ERROR: $1\n"; exit 1; }

# SUDO keepalive

sudo -v
( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID' EXIT

# HOST SETUP

log "Host setup"

sudo apt-get update
sudo apt-get -y install libpam-pwquality

cat <<EOF > ~/.hadk.env
export ANDROID_ROOT="$HOME/hadk"
export VENDOR="nothing"
export DEVICE="spacewar"
export PORT_ARCH="aarch64"
EOF

echo 'function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; } hadk' > ~/.mersdk.profile

cat <<EOF > ~/.mersdkubu.profile
function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
export PS1="HABUILD_SDK [\${DEVICE}] $PS1"
hadk
EOF

export PLATFORM_SDK_ROOT=/srv/sailfishos

# SDK INSTALL

log "Installing PlatformSDK"

curl -k -O https://releases.sailfishos.org/sdk/installers/latest/Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2

sudo mkdir -p $PLATFORM_SDK_ROOT/sdks/sfossdk

sudo tar --numeric-owner -p -xjf Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2 \
    -C $PLATFORM_SDK_ROOT/sdks/sfossdk

# ENTER PLATFORM SDK
log "Entering Platform SDK"

$PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot <<'EOF_PLATFORM'

set -euo pipefail

echo "[+] Inside PlatformSDK"

sudo zypper ref
sudo zypper in -y android-tools-hadk kmod createrepo_c nano ncurses

source ~/.hadk.env

TARBALL=ubuntu-focal-20210531-android-rootfs.tar.bz2
curl -O https://releases.sailfishos.org/ubu/$TARBALL

UBUNTU_CHROOT=$PLATFORM_SDK_ROOT/sdks/ubuntu
sudo mkdir -p $UBUNTU_CHROOT
sudo tar --numeric-owner -xjf $TARBALL -C $UBUNTU_CHROOT

sudo chroot $UBUNTU_CHROOT /bin/bash -c "chage -M 999999 $(id -nu 1000)"

# ENTER HABUILD (UBUNTU CHROOT)

ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu <<'EOF_UBU'

set -euo pipefail

echo "[+] Inside HABUILD"

source ~/.hadk.env

sudo apt-get update
sudo apt-get install -yq \
    cpio bc bison build-essential ccache curl flex g++-multilib gcc-multilib git \
    gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev \
    liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev \
    libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools \
    xsltproc zip zlib1g-dev openjdk-8-jdk python-is-python3

# REPO SETUP

curl http://commondatastorage.googleapis.com/git-repo-downloads/repo -o repo
sudo mv repo /usr/bin/
sudo chmod +x /usr/bin/repo

git config --global user.name "YourName"
git config --global user.email "you@example.com"

mkdir -p $ANDROID_ROOT
cd $ANDROID_ROOT

repo init -u https://github.com/mer-hybris/android.git -b hybris-21.0
git clone https://github.com/SailfishOSSpacewar/sailfish_manifest_spacewar.git .repo/local_manifests

repo sync --fetch-submodules -j$(nproc)

# BUILD

./hybris-patches/apply-patches.sh --mb

source build/envsetup.sh
export USE_CCACHE=1
breakfast $DEVICE

make -j$(nproc) hybris-hal droidmedia
make audio.hidl_compat.default

# INSTAL SHIPPED KERNEL AND MODULES

cd $ANDROID_ROOT/out/target/product/$DEVICE/

mv hybris-boot.img bak || true
mv vendor_boot.img vbak || true

wget -q https://github.com/SailfishOSSpacewar/Releases/raw/refs/heads/main/hybris-boot.img
wget -q https://github.com/SailfishOSSpacewar/Releases/raw/refs/heads/main/vendor_boot.img

cd vendor_dlkm/lib/modules/

sudo rm -rf *
wget -q https://github.com/SailfishOSSpacewar/Releases/raw/refs/heads/main/modules.tar
tar xvf modules.tar
rm modules.tar

# INSTALL SDK TARGETS

cd $ANDROID_ROOT

sdk-assistant create SailfishOS-latest \
https://releases.sailfishos.org/sdk/targets/Sailfish_OS-latest-Sailfish_SDK_Tooling-i486.tar.7z

sdk-assistant create $VENDOR-$DEVICE-$PORT_ARCH \
https://releases.sailfishos.org/sdk/targets/Sailfish_OS-latest-Sailfish_SDK_Target-aarch64.tar.7z

exit
EOF_UBU

# BACK TO PLATFORMSDK

echo "[+] Back to PlatformSDK"

source ~/.hadk.env

cd $ANDROID_ROOT/hybris/droid-configs
git submodule update --init --recursive

cd $ANDROID_ROOT/hybris/droid-config-Spacewar
git submodule update --init --recursive

cd $ANDROID_ROOT

rpm/dhd/helpers/build_packages.sh --droid-hal
rpm/dhd/helpers/build_packages.sh --configs

printf "all\n" | rpm/dhd/helpers/build_packages.sh --mw

# PATCH HWCOMPOSER

cd $ANDROID_ROOT/hybris/mw
rm -rf qt5-qpa-hwcomposer-plugin

git clone https://github.com/mer-hybris/qt5-qpa-hwcomposer-plugin.git
cd qt5-qpa-hwcomposer-plugin
git reset --hard 5.6.2.26

cd $ANDROID_ROOT

rpm/dhd/helpers/build_packages.sh -o -b hybris/mw/qt5-qpa-hwcomposer-plugin

# Now build the rest

rpm/dhd/helpers/build_packages.sh --mw=https://github.com/SailfishOSSpacewar/droid-hal-img-boot-Spacewar
rpm/dhd/helpers/build_packages.sh --mw=https://github.com/SailfishOSSpacewar/droid-system-Spacewar
rpm/dhd/helpers/build_packages.sh --gg
rpm/dhd/helpers/build_packages.sh --version

# Pack rootfs and create zip

sudo zypper in -y lvm2 atruncate pigz android-tools

export RELEASE=5.0.0.67
export EXTRA_NAME=-auto
srcks=$ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
sed -i "s @DEVICEMODEL@ $DEVICE " $srcks

rpm/dhd/helpers/build_packages.sh --mic

EOF_PLATFORM

log "BUILD COMPLETED SUCCESSFULLY"
