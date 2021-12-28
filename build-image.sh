set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build
git clone --depth=1 http://github.com/vyos/vyos-build vyos-build
for a in $(find build -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
	echo "Copying package: $a"
	cp $a vyos-build/packages/
done

cd vyos-build

# Kernel version
KERNEL_FILE=$(ls packages/linux-image*|grep -v dbg_)
KERNEL_VERSION=$(dpkg -I $KERNEL_FILE | sed -ne "s/.*Version: \(.*\)-[0-9]/\1/p")
KERNEL_FLAVOR=$(dpkg -I $KERNEL_FILE | sed -ne "s/.*Package: linux-image-[^-]*-\(.*\)/\1/p")

# Update kernel to current version
jq ".kernel_version=\"$KERNEL_VERSION\" | .kernel_flavor=\"$KERNEL_FLAVOR\" | .architecture=\"arm64\"" data/defaults.json > data/defaults.json.tmp
mv data/defaults.json.tmp data/defaults.json

# Update vyos-base.list
grep -qxF 'firmware-brcm80211' data/live-build-config/package-lists/vyos-base.list.chroot || echo 'firmware-brcm80211' >> data/live-build-config/package-lists/vyos-base.list.chroot

echo "Copy new default configuration to the vyos image"
cp ${ROOTDIR}/config.boot.default data/live-build-config/includes.chroot/opt/vyatta/etc/config.boot.default

# Build the image
VYOS_BUILD_FLAVOR=data/generic-arm64.json ./configure
make iso

cd $ROOTDIR

# Build u-boot
bash build-u-boot.sh

# Generate CM4 image from the iso
# DEVTREE="bcm2711-rpi-cm4" PIVERSION=4 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI4 image from the iso
DEVTREE="bcm2711-rpi-4-b" PIVERSION=4 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI3B image from the iso
#DEVTREE="bcm2710-rpi-3-b" PIVERSION=3 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Generate PI3B+ image from the iso
#DEVTREE="bcm2710-rpi-3-b-plus" PIVERSION=3 bash build-pi-image.sh vyos-build/build/live-image-arm64.hybrid.iso

# Symlink pi4 image
#ln -s vyos-build/build/live-image-arm64.hybrid.img live-image-arm64.hybrid.img
