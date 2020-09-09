#!/bin/sh
#
# Parse kernel command line for variables needed to pass to library functions

export acme_server=$(getarg acme_server=)
export acme_email=$(getarg acme_email=)

export dropbear_auth_key=$(getarg dropbear_auth_key=)
export dropbear_notify_url=$(getarg dropbear_notify_url=)
# Optional params
export dropbear_wait_files=$(getarg dropbear_wait_files=)
if [ -z "$dropbear_wait_files" ]; then
  export dropbear_wait_files=/client.cert,/client.key
fi
export dropbear_sleep_time=$(getarg dropbear_sleep_time=)
if [ -z "$dropbear_sleep_time" ]; then
  export dropbear_sleep_time=5
fi

export nfs_mount=$(getarg nfs_mount=)
export nfs_files=$(getarg nfs_files=)

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
if [ "$root" == "anchor" ]; then
  export rootok=1
fi
