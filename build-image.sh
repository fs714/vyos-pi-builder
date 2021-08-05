set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
# rm -rf vyos-build
# git clone --depth=1 http://github.com/vyos/vyos-build vyos-build
# for a in $(find build -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
# 	echo "Copying package: $a"
# 	cp $a vyos-build/packages/
# done

# If using self build kernel, plese copy kernel files to vyos-build/packages/

cd vyos-build

#Kernel version
KERNEL_FILE=$(ls packages/linux-image*|grep -v dbg_)
KERNEL_VERSION=$(dpkg -I $KERNEL_FILE | sed -ne "s/.*Version: \(.*\)-[0-9]/\1/p")
KERNEL_FLAVOR=$(dpkg -I $KERNEL_FILE | sed -ne "s/.*Package: linux-image-[^-]*-\(.*\)/\1/p")

# Update kernel to current version
jq ".kernel_version=\"$KERNEL_VERSION\" | .kernel_flavor=\"$KERNEL_FLAVOR\" | .architecture=\"arm64\"" data/defaults.json > data/defaults.json.tmp
sed -i '/repo.saltstack.com/d' data/defaults.json.tmp
mv data/defaults.json.tmp data/defaults.json

# Disable syslinux
sed -i "s/--bootloader syslinux,grub-efi/--bootloader grub-efi/" scripts/live-build-config
sed -i "s/--debian-installer none/--debian-installer false/" scripts/live-build-config
sed -i "s/--include=apt-utils,ca-certificates,gnupg2/--include=apt-utils,ca-certificates,gnupg2,apt-transport-https,openssl/" scripts/live-build-config
sed -i '/--utc-time true/d' scripts/live-build-config

# Update buster.pref
sed -i "s/Pin-Priority: -10/Pin-Priority: 100/" data/live-build-config/archives/buster.pref.chroot

# Update vyos-base.list
grep -qxF 'firmware-brcm80211' data/live-build-config/package-lists/vyos-base.list.chroot || echo 'firmware-brcm80211' >> data/live-build-config/package-lists/vyos-base.list.chroot

# Remove openvmtools hooks that are not needed on arm
rm -rf data/live-build-config/hooks/live/30-openvmtools-configs.chroot

echo "Copy new default configuration to the vyos image"
cp ${ROOTDIR}/config.boot.default data/live-build-config/includes.chroot/opt/vyatta/etc/config.boot.default

# Build the image
./configure
make iso

cd $ROOTDIR

# Build u-boot
bash build-u-boot.sh

# Install some needed dependencies for image build that is not in the container
apt update
apt install -y parted udev zip

# Generate CM4 image from the iso
# DEVTREE="bcm2711-rpi-cm4" PIVERSION=4 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI4 image from the iso
DEVTREE="bcm2711-rpi-4-b" PIVERSION=4 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI3B image from the iso
# DEVTREE="bcm2710-rpi-3-b" PIVERSION=3 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI3B+ image from the iso
# DEVTREE="bcm2710-rpi-3-b-plus" PIVERSION=3 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Symlink pi4 image
#ln -s vyos-build/build/live-image-arm64.hybrid.img live-image-arm64.hybrid.img
