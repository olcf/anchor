#!/bin/sh
#
# Run dropbear server to get valid certificate
#
# Reads in the following from the passed environment
#   * $dropbear_auth_key: Root public key to trust. Required
#   * $dropbear_notify_url: URL to curl after dropbear server is setup
#   * $dropbear_wait_files: Comma separated list of the files. Dropbear server
#     is stopped when these files exist. Default `client.cert,client.key`
#   * $dropbear_sleep_time: Seconds to sleep between curls. Default `5`
#
# Outputs client certificate and private key to /client.cert and /client.key
# respectively

# Start dropbear server
dropbear_start_server() {
  HOSTNAME="$(cat /proc/sys/kernel/hostname)"

  info "dropbear: Installing authorized root key"
  mkdir -p /root/
  mkdir -p /root/.ssh
  cp "$dropbear_auth_key" /root/.ssh/authorized_keys

  info "dropbear: Getting certificate for ${HOSTNAME} over SSH connection"

  info "dropbear: Starting Dropbear server"
  mkdir -p /etc/dropbear
  dropbear -E -R
}

# Wait until files are put in place. If configured, notify server while waiting
dropbear_wait() {
  info "dropbear: Files to wait on are $dropbear_wait_files"

  for file in $(echo "$dropbear_wait_files" | sed "s/,/ /g"); do
    info "dropbear: Waiting on $file"
    while [ ! -f "$file" ]; do
      if [ ! -z "$dropbear_notify_url" ]; then dropbear_notify_server; fi
      sleep "$dropbear_sleep_time";
    done
  done
}

# Stop dropbear server
dropbear_stop_server() {
  info "dropbear: Stopping Dropbear server"
  kill "$(cat /var/run/dropbear.pid)"
}

# Ping the server to let it know we're trying to boot. Collect and provide
# local client facts
#
# Hinges on bootif being avail
dropbear_notify_server() {
  mac="$BOOTIF"
  hostname="$(cat /proc/sys/kernel/hostname | cut -d '.' -f 1)"
  domain="$(cat /proc/sys/kernel/hostname | cut -d '.' -f 2-)"
  dev=$(grep -o -i "$mac" /sys/class/net/*/address | cut -d '/' -f 5)
  addr=$(ip addr show dev "$dev" | \
    grep -o -E "inet [0-9,\.,\/]+" | sed "s/inet //")
  addr6=$(ip addr show dev "$dev" | \
    grep -o -E "inet6 [0-9,\.,\/]+" | sed "s/inet6 //")

  curl "$dropbear_notify_url?mac=${mac}&domain=${domain}&dev=${dev}&addr=${addr}&addr6=${addr6}"
}
