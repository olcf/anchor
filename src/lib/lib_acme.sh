#!/bin/sh
#
# Run lego to get an HTTP certificate from an ACME server
#
# Reads in the following from the passed environment
#   * $acme_server:     ACME Server to poll for a certificate
#   * $acme_email:      Email address to use for ACME account
# Uses the file /ca.pem as the ACME server's issuing and TLS CA
#
# Outputs client certificate and private key to /client.cert and /client.key
# respectively

. /lib/lib_rngd.sh

acme_get_certificate() {
  HOSTNAME="$(cat /proc/sys/kernel/hostname)"

  rngd_start
  info "Getting certificate for ${HOSTNAME} from ${acme_server}"
  LEGO_CA_CERTIFICATES=/ca.pem lego --email "${acme_email}" \
    --accept-tos \
    --server "https://${acme_server}" --path /lego \
    --http --domains "${HOSTNAME}" run
  rngd_kill

  # Move certs to / and remove /lego
  info "Certificate issued. Installing"
  mv "/lego/certificates/${HOSTNAME}.crt" /client.cert
  mv "/lego/certificates/${HOSTNAME}.key" /client.key
  rm -rf /lego
}
