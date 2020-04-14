#!/bin/sh
#
# Run rngd to generate data in /dev/random
#

rngd_start() {
  info "rngd: Start rngd daemon"

  # Use pseudo-random as input in case there's not a hw rng available
  rngd -r /dev/urandom

  # Wait until randomness is populated
  while true; do
    read entropy_avail < /proc/sys/kernel/random/entropy_avail
    read read_wakeup_threshold < /proc/sys/kernel/random/read_wakeup_threshold
    # shellcheck disable=SC2086
    if [ $entropy_avail -gt $read_wakeup_threshold ]; then
      info "rngd: $entropy_avail bits of entropy available. Resuming."
      break
    else
      info "rngd: $entropy_avail bits of entropy available. Sleeping."
      sleep 1
    fi
  done
}

rngd_kill() {
  # Kill rngd
  kill "$(cat /var/run/rngd.pid)"
}
