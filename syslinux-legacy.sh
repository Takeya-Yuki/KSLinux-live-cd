#!/bin/bash
mkdir chroot
debootstrap bionic chroot http://mirrors.aliyun.com/ubuntu
mount --bind /dev chroot/dev

cp /etc/hosts chroot/etc/hosts
cp /etc/resolv.conf chroot/etc/resolv.conf
cp /etc/apt/sources.list chroot/etc/apt/sources.list
chroot chroot mount none -t proc /proc
chroot chroot mount none -t sysfs /sys
chroot chroot mount none -t devpts /dev/pts

yes 123456 | chroot chroot passwd

chroot chroot apt update
chroot chroot apt-get install --yes dbus
chroot chroot dbus-uuidgen > /var/lib/dbus/machine-id

chroot chroot apt-get install --yes ubuntu-standard casper lupin-casper
chroot chroot apt-get install --yes discover laptop-detect os-prober
chroot chroot apt-get install --yes linux-signed-generic 

chroot chroot rm /var/lib/dbus/machine-id
chroot chroot apt-get clean
chroot chroot rm -rf /tmp/*
chroot chroot rm /etc/resolv.conf

chroot chroot umount /proc
chroot chroot umount /sys
chroot chroot umount /dev/pts
umount chroot/dev

mkdir -p image/{casper,isolinux,install}

cp chroot/boot/vmlinuz-4.15.*-generic image/casper/vmlinuz
cp chroot/boot/initrd.img-4.15.*-generic image/casper/initrd.lz

cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
cp /boot/memtest86+.bin image/install/memtest

mkdir -p image/isolinux
cp -Rv /usr/lib/syslinux/modules/bios/*.c32 image/isolinux/
cat > image/isolinux/isolinux.cfg << EOF
DEFAULT live
LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 300
PROMPT 1 

#prompt flag_val
# 
# If flag_val is 0, display the "boot:" prompt 
# only if the Shift or Alt key is pressed,
# or Caps Lock or Scroll lock is set (this is the default).
# If  flag_val is 1, always display the "boot:" prompt.
#  http://linux.die.net/man/1/syslinux   syslinux manpage 
EOF

sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE 
do
        sudo sed -i "/${i}/d" image/casper/filesystem.manifest-desktop
done

mksquashfs chroot image/casper/filesystem.squashfs -e boot
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

cat > image/README.diskdefines <<EOF
#define DISKNAME  Ubuntu Remix
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  i386
#define ARCHi386  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

touch image/ubuntu

mkdir image/.disk
cd image/.disk
touch base_installable
echo "full_cd/single" > cd_type
echo "Ubuntu Remix 14.04" > info  # Update version number to match your OS version
echo "http//your-release-notes-url.com" > release_notes_url
cd ../..

(cd image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)

cd image
sudo mkisofs -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../ubuntu-remix.iso .
cd ..

