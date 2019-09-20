#!/bin/sh
#
# Run dropbear server to get valid certificate
#
# Outputs client certificate and private key to /client.cert and /client.key
# respectively

dropbear_get_certificate() {
  HOSTNAME="$(cat /proc/sys/kernel/hostname)"

  info "Getting certificate for ${HOSTNAME} over SSH connection"

  info "Starting Dropbear server"
  dropbear -F -E

  info "Waiting on /client.cert"
  while [ ! -f /client.cert ]; do sleep 1; done

  info "Waiting on /client.key"
  while [ ! -f /client.key ]; do sleep 1; done

  info "Stopping Dropbear server"
  kill "$(cat /var/run/dropbear.pid)"
}
