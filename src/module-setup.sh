#!/bin/sh -xv
#
# Install script for anchor dracut module
#

# List of binaries to install
# Install lego to get self-signed certificate
# Install dropbear to receive certificate
# Install buildah to download and mount images
# Install mksquashfs to create new squashfs live
# Install rngd to populate /dev/random
bin_list="lego dropbear buildah.static mksquashfs.static rngd"

# Include this dracut module if the prerequisites for the module are present
check() {
  # Check if all binaries in bin_list are available
  # If not, return 1. Otherwise return 0
  for bin in $bin_list; do
    test -e "$(which "$bin")" || return 1
  done

 return 0
}

# echo all other dracut module on which this dracut modue depends
# Install curl for HTTPS squashfs image download
# Install nfs for mount and squashfs image copy
depends() {
  echo network url-lib nfs
}

# Install needed kernel modules
installkernel() {
  instmods overlay squashfs loop
}

# install a non-kernel dracut module
install() {

  # Install module library files to /lib
  inst "$moddir/lib/lib_acme.sh" /lib/lib_acme.sh
  inst "$moddir/lib/lib_squashfs.sh" /lib/lib_squashfs.sh
  inst "$moddir/lib/lib_buildah.sh" /lib/lib_buildah.sh
  inst "$moddir/lib/lib_overlayfs.sh" /lib/lib_overlayfs.sh
  inst "$moddir/lib/lib_dropbear.sh" /lib/lib_dropbear.sh
  inst "$moddir/lib/lib_rngd.sh" /lib/lib_rngd.sh
  inst "$moddir/lib/lib_nfs.sh" /lib/lib_nfs.sh
  inst "$moddir/anchor_auth.sh" /lib/anchor_auth.sh
  inst "$moddir/anchor_image.sh" /lib/anchor_image.sh

  # Install unix tools for dracut module
  inst_multiple sed tr cut
  # Install rsync for overlayfs creation
  inst_multiple rsync

  # Install needed binaries
  for bin in $bin_list; do
    inst "$(which "$bin")" "/bin/$bin"
  done

  inst_hook cmdline 95 "$moddir/option_parser.sh"

  inst_hook mount 96 "$moddir/mount_anchor.sh"
}
