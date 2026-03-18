SailfishOS
===========

Getting started
---------------
```
sudo apt-get update && sudo apt-get -y install libpam-pwquality
```
## Setup Export Devices $HOST
~/.hadk.env
```
cat <<EOF > ~/.hadk.env
export ANDROID_ROOT="$HOME/hadk"
export VENDOR="nothing"
export DEVICE="Spacewar"
export PORT_ARCH="aarch64"
EOF
```
~/.mersdk.profile
```
echo 'function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; } hadk' > ~/.mersdk.profile
```
~/.mersdkubu.profile
```
cat <<EOF > ~/.mersdkubu.profile
function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
export PS1="HABUILD_SDK [\${DEVICE}] $PS1"
hadk
EOF
```
## Setup SFOS SDK $HOST
```
export PLATFORM_SDK_ROOT=/srv/sailfishos
```
```
curl -k -O https://releases.sailfishos.org/sdk/installers/latest/Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2
```
```
sudo mkdir -p $PLATFORM_SDK_ROOT/sdks/sfossdk
```
```
sudo tar --numeric-owner -p -xjf Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2 -C $PLATFORM_SDK_ROOT/sdks/sfossdk
```
```
echo "export PLATFORM_SDK_ROOT=$PLATFORM_SDK_ROOT" >> ~/.bashrc
```
```
echo 'alias sfossdk=$PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot' >> ~/.bashrc; exec bash
```
```
echo 'PS1="PlatformSDK $PS1"' > ~/.mersdk.profile
```
```
echo '[ -d /etc/bash_completion.d ] && for i in /etc/bash_completion.d/*;do . $i;done' >> ~/.mersdk.profile
```
```
sfossdk
```
```
sudo zypper ref
```
```
sudo zypper in android-tools-hadk kmod createrepo_c nano
```
```
source ~/.hadk.env
```
## Setup Ubuntu SDK $PlatformSDK
```
TARBALL=ubuntu-focal-20210531-android-rootfs.tar.bz2
```
```
curl -O https://releases.sailfishos.org/ubu/$TARBALL
```
```
UBUNTU_CHROOT=$PLATFORM_SDK_ROOT/sdks/ubuntu
```
```
sudo mkdir -p $UBUNTU_CHROOT
```
```
sudo tar --numeric-owner -xjf $TARBALL -C $UBUNTU_CHROOT
```
```
sudo chroot $UBUNTU_CHROOT /bin/bash -c "chage -M 999999 $(id -nu 1000)"
```
```
ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu
```
```
source ~/.hadk.env
```
## Packages Setup $HABUILD_SDK
```
sudo apt-get update
```
```
sudo apt install cpio bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5-dev libncurses5 libsdl1.2-dev libssl-dev libwxgtk3.0-gtk3-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev openjdk-8-jdk python-is-python3 -yq
```
- Repo setup
```
curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > repo
```
```
sudo mv repo /usr/bin/
```
```
sudo chmod a+x /usr/bin/repo
```
## Sync $HABUILD_SDK
git setup
```
git config --global user.name "Your Name"
```
```
git config --global user.email "you@example.com"
```
repo sync
```
sudo mkdir -p $ANDROID_ROOT
```
```
sudo chown -R $USER $ANDROID_ROOT
```
```
cd $ANDROID_ROOT
```
```
repo init -u https://github.com/mer-hybris/android.git -b hybris-21.0
```
```
git clone https://github.com/SailfishOSSpacewar/sailfish_manifest_Spacewar.git .repo/local_manifests
```
```
repo sync --fetch-submodules -j$(nproc --all)
```
## Patches hybris $HABUILD_SDK
```
./hybris-patches/apply-patches.sh --mb
```
## Build $HABUILD_SDK
```
source build/envsetup.sh
```
```
export USE_CCACHE=1
```
<!-- ```
export TEMPORARY_DISABLE_PATH_RESTRICTIONS=true
```-->
```
breakfast $DEVICE
```
The following command will take time! Grab a coffee and relax (or go touch the grass or whatever)
```
make -j$(nproc --all) hybris-hal droidmedia
```
> if you want check kernel defconfig: hybris/mer-kernel-check/mer_verify_kernel_config ./out/target/product/$DEVICE/obj/KERNEL_OBJ/.config
## Install Tooling $PlatformSDK
```
sdk-assistant create SailfishOS-latest https://releases.sailfishos.org/sdk/targets/Sailfish_OS-latest-Sailfish_SDK_Tooling-i486.tar.7z
```
```
sdk-assistant create $VENDOR-$DEVICE-$PORT_ARCH https://releases.sailfishos.org/sdk/targets/Sailfish_OS-latest-Sailfish_SDK_Target-aarch64.tar.7z
```
## Build Droid HAL Building the droid-hal-device packages $PlatformSDK
```
cd $ANDROID_ROOT
```
```
rpm/dhd/helpers/build_packages.sh --droid-hal
```
<!-- ```
sdk-assistant maintain $VENDOR-$DEVICE-$PORT_ARCH zypper -n --plus-repo $ANDROID_ROOT/droid-local-repo/$DEVICE install --allow-unsigned-rpm hybris-libsensorfw-qt5 mce-plugin-libhybris ngfd-plugin-native-vibrator pulseaudio-modules-droid qtscenegraph-adaptation
```
```
sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -m sdk-install zypper in droid-config-$DEVICE -ofono-configs-binder
``` -->
```
rpm/dhd/helpers/build_packages.sh --configs
```
```
rpm/dhd/helpers/build_packages.sh --mw
```
Type "yes" (or just press enter) to compile all the middleware files EXCEPT the last one : qt5-qpa-hwcomposer-plugin
Instead, we need to use the version with latest tag (5.6.2.26 on this day, March 17 2026):
```
cd $ANDROID_ROOT/hybris/mw
```
```
git clone https://github.com/mer-hybris/qt5-qpa-hwcomposer-plugin.git
```
```
cd qt5-qpa-hwcomposer-plugin
```
```
git reset --hard 5.6.2.26
```
```
cd $ANDROID_ROOT
```
```
rpm/dhd/helpers/build_packages.sh -o -b hybris/mw/qt5-qpa-hwcomposer-plugin
```
```
rpm/dhd/helpers/build_packages.sh --mw=https://github.com/SailfishOSSpacewar/droid-hal-img-boot-Spacewar
```
The following command will take time depending on $HOST performance (around 30min on Xeon 6-cores, 16GB RAM)
```
rpm/dhd/helpers/build_packages.sh --mw=https://github.com/SailfishOSSpacewar/droid-system-Spacewar
```
After that, continue with these commands :
```
rpm/dhd/helpers/build_packages.sh --gg
```
```
rpm/dhd/helpers/build_packages.sh --version
```
# Build SailfishOS (LVM based)
[Version](https://en.wikipedia.org/wiki/Sailfish_OS#Version_history)
```
export RELEASE=5.0.0.62
```
Put whatever you want here, i.e my1
```
export EXTRA_NAME=-my1
```
```
sudo zypper in lvm2 atruncate pigz android-tools
```
```
cd $ANDROID_ROOT
```
```
srcks=$ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
```
```
sed -i "s @DEVICEMODEL@ $DEVICE " $srcks
```
```
rpm/dhd/helpers/build_packages.sh --mic
```

[**If you want support, tell me**](https://t.me/nc1x72)
