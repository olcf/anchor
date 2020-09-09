#!/bin/sh
#
# Handle authentication pieces

# Source needed libraries
. /lib/lib_acme.sh
. /lib/lib_dropbear.sh
. /lib/lib_nfs.sh

anchor_auth() {
  # Get client certificate
  if [ ! -z "$acme_server" ] && [ ! -z "$acme_email" ]; then
    acme_get_certificate
  elif [ ! -z "$dropbear_auth_key" ]; then
    dropbear_start_server
    dropbear_wait
    dropbear_stop_server
  elif [ ! -z "$nfs_mount" ] && [ ! -z "$nfs_files" ]; then
    nfs_mount_copy
  fi

}
