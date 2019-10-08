#!/bin/bash
env

RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
#YELLOW='\033[00;33m'

OK=$(echo -e "[ ${GREEN}OK${RESTORE} ]")
FAILED=$(echo -e "[ ${RED}FAILED${RESTORE} ]")

## Test if variables set. If not, exit

# From environment.sh
if [ -z "$PUPPET_BRANCH" ]; then
  echo "$FAILED PUPPET_BRANCH not set! Exiting"
  exit 1
fi

# From branch name
if [ -z "$IMAGE_SUFFIX" ]; then
  echo "$FAILED IMAGE_SUFFIX not set! Exiting"
  exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "$FAILED CLUSTER_NAME not set! Exiting"
  exit 1
fi

if [ -z "$PUPPET_ROLE" ]; then
  echo "$FAILED PUPPET_ROLE not set! Exiting"
  exit 1
fi

if [ -z "$MESSAGE" ]; then
  echo "$FAILED MESSAGE not set! Exiting"
  exit 1
fi

################################################################################

## SCRIPT VARIABLES

KEY_NAME=${CLUSTER_NAME}_shared

################################################################################

function collect_facts() {

  echo -en "Setting additional facts..."

  # Trick puppet that we're a managed_image_client
  touch /image-build.log

  FACTD="/opt/puppetlabs/facter/facts.d"

  mkdir -p "${FACTD}"

  { echo "managed_image_name=${PUPPET_ROLE}";
    echo "managed_image_target=${PUPPET_ROLE}";
  } >> "${FACTD}"/image_facts.txt


  if [ -e "${FACTD}"/image_facts.txt ]; then
    echo -e "${OK}"
  else
    echo -e "${FAILED}"
    exit 1
  fi

}

# Put puppet config in place before puppet runs
function place_puppet_conf() {
  echo -en "Placing puppet.conf..."

  mkdir -p "/etc/puppetlabs/puppet"
  cat <<-EOF > /etc/puppetlabs/puppet/puppet.conf
[main]
    codedir = /etc/puppetlabs/code
    server = puppet.example.com
    ca_server = puppetca.example.com
    vardir = /var/cache/puppet

[agent]
    environment = $PUPPET_BRANCH
    daemonize = false
    onetime = true
    usecacheonfailure = false
    classfile = \$vardir/classes.txt
    show_diff = false
    node_name_fact = image_node_name
    certname = ${KEY_NAME}
EOF

  if [ $? -eq 0 ]; then
          echo "${OK}"
  else
          echo "${FAILED}"
          exit 1
  fi

}

# Generate new ssh hostkeys for an image
function generate_ssh_keys() {
  mkdir -p "${IMAGE}"/etc/ssh
  for type in ecdsa ed25519 rsa; do
    ssh-keygen -q -C '' -N '' -t ${type} -f "${IMAGE}"/etc/ssh/ssh_host_${type}_key
  done
}


function chroot_puppet() {

  # Testing for now, but run puppet on host
  echo 'NETWORKING=yes' > /etc/sysconfig/network

  echo "Starting first puppet run..."
  /opt/puppetlabs/bin/puppet agent --test --environment="${PUPPET_BRANCH}" --node_name_value="${PUPPET_ROLE}";
  echo "${OK} First puppet run complete"
  echo "Starting second puppet run..."
  /opt/puppetlabs/bin/puppet agent --test --environment="${PUPPET_BRANCH}" --node_name_value="${PUPPET_ROLE}";
  echo "${OK} Second puppet run complete"
  echo "Starting third puppet run..."
  /opt/puppetlabs/bin/puppet agent --test --environment="${PUPPET_BRANCH}" --node_name_value="${PUPPET_ROLE}";
  echo "${OK} Third puppet run complete"

  /opt/puppetlabs/bin/puppet facts

  # Debugging to check ssh keys
  find /etc/ssh/ -type f

}


function clean_up_image() {

  if [ -e "/usr/lib/systemd/system/ebtables.service" ]; then
    chmod -x /usr/lib/systemd/system/ebtables.service*
  fi
  if [ -e "/usr/lib/systemd/system/wpa_supplicant.service" ]; then
    chmod -x /usr/lib/systemd/system/wpa_supplicant.service*
  fi

  bash -c "yum clean all >/dev/null 2>&1"

  systemd-firstboot --timezone=America/New_York --locale=en_US.UTF-8 --locale-messages=en_US.UTF-8

}

###############################################

# Distilling to just set facts, copy puppet conf and keys, run puppet
collect_facts
place_puppet_conf
generate_ssh_keys
chroot_puppet
clean_up_image
