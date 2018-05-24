#!/bin/bash
# Various routines to mangle the Raspberry pi image

mount_image_partition() {
  local _image="$1"
  local _partName=$2
  local _mountpoint="$3"

  local _sector=$( fdisk -l "${_image}" | grep ${_partName} | awk '{ print $2 }' )
  local _offset=$(( ${_sector} * 512 ))

  [ ! -d "${_mountpoint}" ] && mkdir -p "${_mountpoint}"
  mount "${_image}" -o offset=${_offset} "${_mountpoint}"
}

# SSH
# The pi image uses a simple file 'ssh' in the boot sector to indicate
# that the SSH daemon should be started. This is a convenience and only applies
# to the Raspbian images.
turn_off_ssh() {
  local _image="$1"

  echo "  Disabling SSH"

  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  mount_image_partition "${_image}" FAT32 tmpmnt
  rm -f tmpmnt/ssh
  umount tmpmnt

  rmdir tmpmnt
}

turn_on_ssh() {
  local _image="$1"

  echo "  Enabling SSH"

  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  [[ "$NO_SSH" == "1" ]] && prefix_trap "turn_off_ssh ${_image}" EXIT
  mount_image_partition "${_image}" FAT32 tmpmnt
  touch tmpmnt/ssh
  umount tmpmnt
  
  rmdir tmpmnt
}

remove_drive_remapping() {
  local _image="$1"

  echo "  Removing drive remapping"

  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  mount_image_partition "${_image}" Linux tmpmnt
  rm -f tmpmnt/etc/udev/rules.d/90-qemu.rules
  umount tmpmnt
  rmdir tmpmnt
}

add_drive_remapping() {
  local _image="$1"

  echo "  Adding drive remapping"

  prefix_trap "remove_drive_remapping ${_image}" EXIT

  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  mount_image_partition "${_image}" Linux tmpmnt
  cat > tmpmnt/etc/udev/rules.d/90-qemu.rules <<EOF
KERNEL=="sda", SYMLINK+="mmcblk0"
KERNEL=="sda?", SYMLINK+="mmcblk0p%n"
KERNEL=="sda2", SYMLINK+="root"
EOF

  umount tmpmnt
  rmdir tmpmnt
}

remove_qemu_arm_patch() {
  echo "  Removing QEMU ARM patch"
  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  mount_image_partition "${_image}" Linux tmpmnt
  sed -i '/^#.*libarmmem.so/s/^#\(.*\)$/\1/' tmpmnt/etc/ld.so.preload

  umount tmpmnt
  rmdir tmpmnt
}

# Work around a known issue with qemu-arm, versatile board and raspbian for at least qemu-arm < 2.8.0
# This works but modifies the image so it is recommended to upgrade QEMU
# Ref: http://stackoverflow.com/questions/38837606/emulate-raspberry-pi-raspbian-with-qemu
apply_qemu_arm_patch() {
  local _image=$1

  local _qemu_version=$( qemu-system-arm --version | grep -oP '\d+\.\d+\.\d+' )
  local _qemu_major=$( echo ${_qemu_version} | head -1 | cut -d. -f1 )
  local _qemu_minor=$( echo ${_qemu_version} | head -1 | cut -d. -f2 )

  [ $_qemu_major -gt 2 ] && echo "  QEMU version (${_qemu_version}) > 2, no ARM patch required" && return
  [ $_qemu_major -eq 2 ] && [ $_qemu_minor -le 8 ] && echo "  QEMU version (${_qemu_version}) >= 2.8, no ARM patch required" && return

  echo "  Applying QEMU ARM patch"
  echo "    (It is recommended that you update your QEMU to the latest version)"
  prefix_trap "remove_qemu_arm_patch ${_image}" EXIT

  [ ! -d "tmpmnt" ] && mkdir -p "tmpmnt"

  mount_image_partition "${_image}" Linux tmpmnt
  sed -i '/^[^#].*libarmmem.so/s/^\(.*\)$/#\1/' tmpmnt/etc/ld.so.preload

  umount tmpmnt
  rmdir tmpmnt
}
