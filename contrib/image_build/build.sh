#!/bin/bash
#
# Build a new image only using buildah. Save everything to granite registry.
#
# Outputs images in the following format
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}

usage() {
  echo "Usage: $0 [--branch <PUPPET_BRANCH>] [--base-image <BASE_IMAGE>] [--role <PUPPET_ROLE>] [--suffix <IMAGE_SUFFIX>] [-m|--message <MESSAGE>] [-r|--registry <REGISTRY_URL>] [-a|--auth <DOCKER_AUTH_FILE>] [-p|--puppet-url <PUPPET_URL>] [-h|--help]"
}

while test -n "${1}"; do
  case "$1" in
    --branch)
      PUPPET_BRANCH=$2
      shift 2
      ;;
    --base-image)
      BASE_IMAGE=$2
      shift 2
      ;;
    --role)
      PUPPET_ROLE=$2
      shift 2
      ;;
    --suffix)
      IMAGE_SUFFIX=$2
      shift 2
      ;;
    -m|--messge)
      MESSAGE=$2
      shift 2
      ;;
    -r|--registry)
      BUILD_REGISTRY_URL=$2
      shift 2
      ;;
    -a|--auth)
      AUTH_FILE=$2
      shift 2
      ;;
    -p|--puppet-url)
      PUPPET_URL=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 1
      ;;
  esac
done

RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
OK=$(echo -e "[ ${GREEN}OK${RESTORE} ]")
FAILED=$(echo -e "[ ${RED}FAILED${RESTORE} ]")

PUPPET_LOG="first-puppet-run.log"

# Create container, copy keys, run build script
setup_container() {
  container=$(buildah from --authfile "${AUTH_FILE}" \
    "${BUILD_REGISTRY_URL}/${BASE_IMAGE}") &&

  # Add puppet keys
  buildah copy "${container}" \
    "/etc/images/puppet_keys/certs/${CERTIFICATE_NAME}.pem" \
    "/etc/puppetlabs/puppet/ssl/certs/${CERTIFICATE_NAME}.pem" &&
  buildah copy "${container}" \
    "/etc/images/puppet_keys/private_keys/${CERTIFICATE_NAME}.pem" \
    "/etc/puppetlabs/puppet/ssl/private_keys/${CERTIFICATE_NAME}.pem" &&
  buildah copy "${container}" \
    "/etc/images/puppet_keys/public_keys/${CERTIFICATE_NAME}.pem" \
    "/etc/puppetlabs/puppet/ssl/public_keys/${CERTIFICATE_NAME}.pem" &&

  # Pass env
  buildah config --env PUPPET_BRANCH="${PUPPET_BRANCH}" "${container}" &&
  buildah config --env PUPPET_ROLE="${PUPPET_ROLE}" "${container}" &&
  buildah config --env PUPPET_URL="${PUPPET_URL}" "${container}" &&
  buildah config --env PUPPET_SERVER="${PUPPET_SERVER}" "${container}" &&
  buildah config --env CERTIFICATE_NAME="${CERTIFICATE_NAME}" "${container}" &&

  # Install this script and run build
  buildah copy "${container}" "$0" /build_image.sh &&
  buildah run "${container}" bash -c ". /build_image.sh; build_image"
  build_image_status=$?
  if [[ "$build_image_status" != 0 ]]; then return $build_image_status; fi
}

function install_puppet() {
  cat > /etc/yum.repos.d/puppet.repo <<EOF
[puppet]
name = puppet
baseurl = ${PUPPET_URL}
gpgcheck = 0
EOF

  echo -e "Installing puppet..."
  yum install -y puppet
}

function collect_facts() {
  echo -e "Setting additional facts..."

  # Trick puppet that we're a managed_image_client
  touch /image-build.log

  FACTD="/opt/puppetlabs/facter/facts.d"

  mkdir -p "${FACTD}"

  { echo "managed_image_name=${PUPPET_ROLE}";
    echo "managed_image_target=${PUPPET_ROLE}";
  } >> "${FACTD}"/image_facts.txt
}

# Put puppet config in place before puppet runs
function place_puppet_conf() {
  echo -e "Placing puppet.conf..."
  mkdir -p "/etc/puppetlabs/puppet"
  cat <<-EOF > /etc/puppetlabs/puppet/puppet.conf
[main]
    codedir = /etc/puppetlabs/code
    server = ${PUPPET_SERVER}
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
    certname = ${CERTIFICATE_NAME}
EOF

  # Testing for now, but run puppet on host
  echo 'NETWORKING=yes' > /etc/sysconfig/network
}

# Generate new ssh hostkeys for an image
function generate_ssh_keys() {
  mkdir -p /etc/ssh
  for type in ecdsa ed25519 rsa; do
    ssh-keygen -q -C '' -N '' -t "${type}" -f "/etc/ssh/ssh_host_${type}_key"
  done
}

# Just run puppet
function run_puppet() {
  echo "Starting puppet run..."
  # Puppet 6 won't use systemd unless it's in /proc/1/comm...
  echo "not systemd" > /proc/1/comm
  /opt/puppetlabs/bin/puppet agent --test --environment="${PUPPET_BRANCH}" --node_name_value="${PUPPET_ROLE}" 3>&1 | tee -a "${PUPPET_LOG}"
  echo "${OK} Puppet run complete"
  echo -e "Clean yum cache"
  yum clean all
}

# Set first boot and add some systemd cleanup
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

# Check if puppet ran successfully on last run
check_puppet() {
  end_log=$(tail -n -1 "${PUPPET_LOG}")
  regexp='Notice: Applied catalog in'
  if ! [[ "$end_log" =~ $regexp ]]; then return 1; fi
}

function build_image() {
  install_puppet
  collect_facts
  place_puppet_conf
  generate_ssh_keys
  run_puppet
  run_puppet
  run_puppet
  clean_up_image
  check_puppet
}

# Annotate and commit container
finalize_container() {
  container_mount=$(buildah mount "${container}") &&

  # Get puppet version image built with
  PUPPET_COMMIT_SHA=$(grep -oP -m 1 \
    "Info: Applying configuration version \'\K\w+(?=')" \
    "${container_mount}/${PUPPET_LOG}") &&

  # Copy resolv.conf into the image
  cat <<-EOF > ${container_mount}/etc/resolv.conf
# search list for host-name lookup
search example.com

# dns.example.com
nameserver 1.1.1.1

# dns1.example.com
nameserver 8.8.8.8

# dns2.example.com
nameserver 8.8.4.4
EOF

  # Store image info in file
  cat <<-EOF > "${container_mount}/${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA:-000000}-${PUPPET_COMMIT_SHA:-000000}" &&
BUILD_REASON="${MESSAGE}"
PUPPET_BRANCH="${PUPPET_BRANCH}"
USER="${USER}"
PUPPET_COMMIT="${PUPPET_COMMIT_SHA}"
PUPPET_BRANCH="${PUPPET_BRANCH}"
IMAGE_SUFFIX="${IMAGE_SUFFIX}"
CERTIFICATE_NAME="${CERTIFICATE_NAME}"
PUPPET_ROLE="${PUPPET_ROLE}"
MESSAGE="${MESSAGE}"
EOF

  # Annotate
  buildah config \
    --label BUILD_REASON="${MESSAGE}" \
    --label PUPPET_BRANCH="${PUPPET_BRANCH}" \
    --label USER="${USER}" \
    --label PUPPET_COMMIT="${PUPPET_COMMIT_SHA}" \
    --label PUPPET_BRANCH="${PUPPET_BRANCH}" \
    --label IMAGE_SUFFIX="${IMAGE_SUFFIX}" \
    --label PUPPET_ROLE="${PUPPET_ROLE}" \
    --label MESSAGE="${MESSAGE}" "${container}"

  # Push new image and short name
  buildah commit --authfile "${AUTH_FILE}" "${container}" \
    "docker://${BUILD_REGISTRY_URL}/${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA:-000000}-${PUPPET_COMMIT_SHA:-000000}"
  buildah commit --authfile "${AUTH_FILE}" "${container}" \
    "docker://${BUILD_REGISTRY_URL}/${PUPPET_ROLE}:${IMAGE_SUFFIX}"
}

# Cleanup container
clean_container() {
  buildah rm "${container}"

  # Try to delete base image, but could fail because the build host has other
  # images that are dependent on it
  buildah rmi "${BUILD_REGISTRY_URL}/${BASE_IMAGE}" || true
}

main() {
  ## Test if variables set. If not, exit
  if [ -z "$PUPPET_BRANCH" ]; then
    echo "$FAILED PUPPET_BRANCH not set! Exiting"
    exit 1
  fi

  if [ -z "$BASE_IMAGE" ]; then
    echo "$FAILED BASE_IMAGE not set! Exiting"
    exit 1
  fi

  if [ -z "$PUPPET_ROLE" ]; then
    echo "$FAILED PUPPET_ROLE not set! Exiting"
    exit 1
  fi

  if [ -z "$IMAGE_SUFFIX" ]; then
    echo "$FAILED IMAGE_SUFFIX not set! Exiting"
    exit 1
  fi

  if [ -z "$MESSAGE" ]; then
    echo "$FAILED MESSAGE not set! Exiting"
    exit 1
  fi

  if [ -z "$BUILD_REGISTRY_URL" ]; then
    echo "$FAILED BUILD_REGISTRY_URL not set! Exiting"
    exit 1
  fi

  if [ -z "$PUPPET_URL" ]; then
    PUPPET_URL=http://mirror.example.com/snapshots/puppet/el-7-x86_64-puppet
  fi

  if [ -z "${CERTIFICATE_NAME}" ]; then
    echo "$FAILED CERTIFICATE_NAME not set! Exiting"
  fi

  # Debugging flag
  set -x
  # We use pipes and sometimes they break. Exit on pipe failures
  set -o pipefail

  # If running or commit fails, exit
  setup_container || exit 1
  finalize_container || exit 1
  clean_container
}

# Run main if this file is not being sourced.
#
# Bash only allows return functions in sourced scripts. Run a dummy return
# command in a subshell and ignore stderr. If exit code is 0, we're able to
# execute return and we are being sourced. Otherwise we aren't allowed to run
# return and we must have been called directly
if ! (return 0 2>/dev/null); then
  main
fi
