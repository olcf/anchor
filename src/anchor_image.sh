#!/bin/sh
#
# Handle image fetching

# Source needed libraries
. /lib/lib_buildah.sh
. /lib/lib_squashfs.sh
. /lib/lib_overlayfs.sh
. /lib/lib_nfs.sh

anchor_image() {
  # Download image flat from container registry, create squashfs, mount
  if [ ! -z "$buildah_registry" ] && [ ! -z "$buildah_image" ]; then
    buildah_install_certificates
    buildah_create_storage
    buildah_mount_image
    squashfs_create_path=$buildah_mountpath squashfs_create
    buildah_cleanup
    squashfs_mount
  # Download compressed squashfs from HTTP(S) or rsync, mount
  elif [ ! -z "$squashfs_server" ]; then
    squashfs_copy_image
    squashfs_mount
  # Mount NFS share, copy compressed squashfs image, mount
  elif [ ! -z "$squashfs_server" ]; then
    nfs_copy_image
    squashfs_mount
  # Mount already in place squashfs
  elif [ ! -z "$squashfs_mount_only" ]; then
    squashfs_mount
  fi
  # Create overlayfs over squashfs
  if [ ! -z "$overlayfs_write" ] && [ ! -z "$overlayfs_size" ]; then
    overlayfs_create
  fi
}
