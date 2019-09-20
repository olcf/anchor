#!/bin/sh
#
# Run the library functions to mount an anchor image

# Source needed libraries
. /lib/lib_acme.sh
. /lib/lib_dropbear.sh
. /lib/lib_squashfs.sh
. /lib/lib_buildah.sh
. /lib/lib_overlayfs.sh

# Get client certificate
if [ ! -z "$acme_server" ] && [ ! -z "$acme_email" ]; then
  acme_get_certificate
elif [ ! -z "$dropbear_auth_key" ]; then
  dropbear_get_certificate
fi

# Download image, create squashfs, mount
if [ ! -z "$buildah_registry" ] && [ ! -z "$buildah_image" ]; then
  buildah_install_certificates
  buildah_create_storage
  buildah_mount_image
  squashfs_create_path=$buildah_mountpath squashfs_create
  buildah_cleanup
  squashfs_mount
# Download squashfs and mount
elif [ ! -z "$squashfs_server" ]; then
  squashfs_copy_image
  squashfs_mount
# Mount squashfs
elif [ ! -z "$squashfs_mount_only" ]; then
  squashfs_mount
fi

# Create overlayfs
if [ ! -z "$overlayfs_write" ] && [ ! -z "$overlayfs_size" ]; then
  overlayfs_create
fi
