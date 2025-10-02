#!/bin/sh
version="${VERSION:-20.5-Nexus}"
source_img_name="CoreELEC-Amlogic-ng.arm-${version}-Generic"
source_img_file="${source_img_name}.img.gz"
source_img_url="https://github.com/CoreELEC/CoreELEC/releases/download/${version}/${source_img_file}"
target_img_prefix="CoreELEC-Amlogic-ng.arm-${version}"
target_img_name="${target_img_prefix}-E900V22C-$(date +%Y.%m.%d)"
mount_point="target"
common_files="common-files"
system_root="SYSTEM-root"
modules_load_path="${system_root}/usr/lib/modules-load.d"
systemd_path="${system_root}/usr/lib/systemd/system"
libreelec_path="${system_root}/usr/lib/libreelec"
config_path="${system_root}/usr/config"
kodi_userdata="${mount_point}/.kodi/userdata"

# Prepare functions
mount_partition() {
  img=$1
  offset=$2
  mount_point=$3
  sudo mount -o loop,offset=${offset} ${img} ${mount_point}
}
unmount_partition() {
  mount_point=$1
  sudo umount -d ${mount_point}
}
copy_with_permissions() {
  src=$1
  dest=$2
  mode=$3
  sudo cp ${src} ${dest}
  sudo chown root:root ${dest}
  sudo chmod ${mode} ${dest}
}

echo "Welcome to build CoreELEC for Skyworth E900V22C!"
echo "Downloading CoreELEC-${version} generic image"
wget -q --show-progress ${source_img_url} -O ${source_img_file} || exit 1
echo "Decompressing CoreELEC image"
gzip -d ${source_img_file} || exit 1

echo "Creating mount point"
mkdir ${mount_point}
echo "Mounting CoreELEC boot partition"
mount_partition ${source_img_name}.img 4194304 ${mount_point}
echo "Copying E900V22C DTB file"
sudo cp ${common_files}/e900v22c.dtb ${mount_point}/dtb.img
echo "Decompressing SYSTEM image"
sudo unsquashfs -d ${system_root} ${mount_point}/SYSTEM

echo "Copying modules-load conf for uwe5621ds"
copy_with_permissions ${common_files}/wifi_dummy.conf ${modules_load_path}/wifi_dummy.conf 0664
echo "Copying systemd service file for uwe5621ds"
copy_with_permissions ${common_files}/sprd_sdio-firmware-aml.service ${systemd_path}/sprd_sdio-firmware-aml.service 0664
sudo ln -s ../sprd_sdio-firmware-aml.service ${systemd_path}/multi-user.target.wants/sprd_sdio-firmware-aml.service
echo "Copying fs-resize script"
copy_with_permissions ${common_files}/fs-resize ${libreelec_path}/fs-resize 0775
echo "Copying rc_keymap files"
copy_with_permissions ${common_files}/rc_maps.cfg ${config_path}/rc_maps.cfg 0664
copy_with_permissions ${common_files}/e900v22c.rc_keymap ${config_path}/rc_keymaps/e900v22c 0664
copy_with_permissions ${common_files}/keymap.hwdb ${config_path}/hwdb.d/keymap.hwdb 0664

echo "Compressing SYSTEM image"
sudo mksquashfs ${system_root} SYSTEM -comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs
echo "Replacing SYSTEM image"
sudo rm ${mount_point}/SYSTEM.md5
sudo rm ${mount_point}/SYSTEM
sudo mv SYSTEM ${mount_point}/SYSTEM
sudo md5sum "${mount_point}/SYSTEM" | sudo tee "${mount_point}/SYSTEM.md5" >/dev/null
sudo rm -rf ${system_root}

echo "Creating keymaps directory for kodi"
sudo mkdir -p -m 0755 ${kodi_userdata}/keymaps
echo "Copying kodi config files"
copy_with_permissions ${common_files}/advancedsettings.xml ${kodi_userdata}/advancedsettings.xml 0644
copy_with_permissions ${common_files}/backspace.xml ${kodi_userdata}/keymaps/backspace.xml 0644

echo "Unmounting CoreELEC data partition"
unmount_partition ${mount_point}
echo "Deleting mount point"
rm -rf ${mount_point}

echo "Rename image file"
mv ${source_img_name}.img ${target_img_name}.img
echo "Compressing CoreELEC image"
gzip ${target_img_name}.img
sha256sum ${target_img_name}.img.gz > ${target_img_name}.img.gz.sha256