#! /bin/sh

# Revision: .000000002
# refrenced from:
# <http://odroid.com/dokuwiki/doku.php?id=en:c1_building_kernel>

apt-get install ntp -y
dpkg-reconfigure tzdata

cd /etc/apt/sources.list.d/
wget http://oph.mdrjr.net/meveric/sources.lists/meveric-all-C1.list
wget -O- http://oph.mdrjr.net/meveric/meveric.asc | apt-key add -
apt-get update

# install the required tools
apt-get install uboot-mkimage -y

# Note, selecting 'libncurses5-dev' instead of 'ncurses-dev'

apt-get install libncurses5-dev -y
apt-get install bc -y
apt-get install lzop -y

apt-get install g++ -y
apt-get install make -y
apt-get install build-essential -y
apt-get install subversion -y
apt-get install git -y

cd /srv
git clone --depth 1 https://github.com/hardkernel/linux.git -b odroidc-3.10.y
cd /srv/linux

# Build The kernel

make odroidc_defconfig
make -j4
make -j4 modules
make uImage
make dtbs

# Installation
# I don't think ARCH=arm is needed, but it does not hurt anything
make modules_install ARCH=arm INSTALL_MOD_PATH=/

# Get the kernel version
KV=`make kernelversion`

# Backup boot files
# The boot partition needs to be RW
mount -o remount,rw /boot

mkdir /srv/new_boot
mkdir /srv/back_boot

# Backup existing boot files
mv /boot/meson8b_odroidc.dtb /srv/back_boot/meson8b_odroidc.dtb
mv /boot/uImage /srv/back_boot/uImage
mv /boot/uInitrd /srv/back_boot/uInitrd

# Stage new boot files
cp arch/arm/boot/dts/meson8b_odroidc.dtb /srv/new_boot
cp arch/arm/boot/uImage /srv/new_boot

update-initramfs -c -k $KV -b /srv/new_boot
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /srv/new_boot/initrd.img-$KV /srv/new_boot/uInitrd

# put the new files in /boot
cp /srv/new_boot/meson8b_odroidc.dtb /boot/meson8b_odroidc.dtb
cp /srv/new_boot/uImage /boot/uImage
cp /srv/new_boot/uInitrd /boot/uInitrd


