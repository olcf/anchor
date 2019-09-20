#!/bin/sh
#
# Run dropbear server to get valid certificate
#
# Reads in the following from the passed environment
#   * $dropbear_auth_key: Root public key to trust
#
# Outputs client certificate and private key to /client.cert and /client.key
# respectively

dropbear_get_certificate() {
  HOSTNAME="$(cat /proc/sys/kernel/hostname)"

  info "dropbear: Installing authorized root key"
  mkdir -p /root/
  mkdir -p /root/.ssh
  cp "$dropbear_auth_key" /root/.ssh/authorized_keys

  info "dropbear: Getting certificate for ${HOSTNAME} over SSH connection"

  info "dropbear: Starting Dropbear server"
  mkdir -p /etc/dropbear
  dropbear -F -E -R

  info "dropbear: Waiting on /client.cert"
  while [ ! -f /client.cert ]; do sleep 1; done

  info "dropbear: Waiting on /client.key"
  while [ ! -f /client.key ]; do sleep 1; done

  info "dropbear: Stopping Dropbear server"
  kill "$(cat /var/run/dropbear.pid)"
}
