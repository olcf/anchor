#!/bin/sh
#
# Parse kernel command line for variables needed to pass to library functions

export acme_server=$(getarg acme_server=)
export acme_email=$(getarg acme_email=)

export dropbear_auth_key=$(getarg dropbear_auth_key=)

export buildah_registry=$(getarg buildah_registry=)
export buildah_image=$(getarg buildah_image=)

export overlayfs_size=$(getarg overlayfs_size=)
export overlayfs_write=$(getarg overlayfs_write=)

export squashfs_curl=$(getarg squashfs_curl=)
export squashfs_rsync=$(getarg squashfs_rsync=)
export squashfs_server=$(getarg squashfs_server=)
export squashfs_mount_only=$(getarg squashfs_mount_only=)

# Set rootok if root set to anchor and boot interface configured
export root=$(getarg root=)
export BOOTIF=$(getarg BOOTIF=)
if [ "$root" == "anchor" ] && [[ ! -z "$BOOTIF" ]]; then
  export rootok=1
fi
