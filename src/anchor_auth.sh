#!/bin/sh
#
# Handle authentication pieces

# Source needed libraries
. /lib/lib_acme.sh
. /lib/lib_dropbear.sh

anchor_auth() {
  # Get client certificate
  if [ ! -z "$acme_server" ] && [ ! -z "$acme_email" ]; then
    acme_get_certificate
  elif [ ! -z "$dropbear_auth_key" ]; then
    dropbear_get_certificate
  fi

}
