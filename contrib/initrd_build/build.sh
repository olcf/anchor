#!/bin/bash
#
# Run buildah to make an initrd
#
# In a base image, install anchor dracut module and dependencies. Run dracut to
# build the initrd. Copy the kernel and initrd to an output directory

usage() {
  echo "Usage: $0 [-r|--registry <REGISTRY_URL] [-b|--base-image <BASE_IMAGE>] [-o|--output-dir <OUTPUT_DIR>] [-a|--auth <DOCKER_AUTH_FILE>] [-h|--help]"
}

while test -n "${1}"; do
  case "$1" in
    -r|--registry)
      BUILD_REGISTRY_URL=$2
      shift 2
      ;;
    -b|--base-image)
      BASE_IMAGE=$2
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR=$2
      shift 2
      ;;
    -a|--auth)
      AUTH_FILE=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 1
      ;;
  esac
done

# Run this function in a container to create an initrd
make_initrd() {
  # Installing yum repos
  cat > /etc/yum.repos.d/os.repo << EOF
[os]
name = os
baseurl = http://mirror.example.com/upstream/rhel/7/x86_64/os/
EOF

  cat > /etc/yum.repos.d/anchor.repo << EOF
[anchor]
name = anchor
baseurl = http://mirror.example.com/custom/anchor/el7-x86_64
gpgcheck = 0
EOF

  # Install kernel
  echo -e "Installing kernel"
  yum install -y kernel kernel-devel microcode_ctl linux-firmware

  # Install binaries
  echo -e "Installing needed binaries"
  yum install -y lego dropbear-static buildah-static squashfs-tools-static

  # Install dracut modules
  echo -e "Installing dracut modules"
  yum install -y dracut-network anchor-dracut-module
  ANCHOR_VERSION="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' \
    anchor-dracut-module)"

  KERNEL_PATH=/boot/
  KERNEL_PATTERN='vmlinuz-'

  # Get the most recent kernel available
  KERNEL=$(find "${KERNEL_PATH}" -name "${KERNEL_PATTERN}*" -printf '%f\n' \
    | sort -nr | head -n 1 | sed "s/${KERNEL_PATTERN}//")

  echo -e "Probing overlay, squashfs, and loop..."
  modprobe overlay squashfs loop mlx4_core mlx4_en mlx4_ib igb bnx2 i40e \
    ipmi_si ipmi_devintf ipmi_msghandler
  # Try and force no-hostonly
  echo "hostonly=no" >> /etc/dracut.conf

  # Build initrd
  #
  # Force install drivers, modules we want, and no hostonly to build generic
  # image
  mkdir -p /output/
  echo -e "Making initrd..."
  dracut -f -m 'kernel-modules anchor network base' --strip -v \
    --no-hostonly --force-drivers \
    "overlay squashfs loop mlx4_core mlx4_en mlx4_ib igb bnx2 i40e ipmi_si ipmi_devintf ipmi_msghandler" \
    "/output/initrd-${KERNEL}-anchor-${ANCHOR_VERSION:-0}" "${KERNEL}"

  cp "/${KERNEL_PATH}/${KERNEL_PATTERN}${KERNEL}" /output
  chmod 655 /output/initrd-*
}

# Run on the host to create a container, copy this file into, and run
# make_initrd
setup_container() {
  container=$(buildah from --authfile "${AUTH_FILE}" \
    "docker://${BUILD_REGISTRY_URL}/${BASE_IMAGE}")

  buildah copy "${container}" "$0" /initrd_build.sh
  buildah run "${container}" bash -c ". /initrd_build.sh; make_initrd"

  mount_path=$(buildah mount "${container}")
  cp -r "${mount_path}/output" "${OUTPUT_DIR}"
  buildah rm "${container}"
  # Try to delete base image, but there's probably other dependent containers
  buildah rmi "${REGISTRY_URL}/${BASE_IMAGE}" || true
}

# Run the setup_container function if this file is not being sourced.
#
# Bash only allows return functions in sourced scripts. Run a dummy return
# command in a subshell and ignore stderr. If exit code is 0, we're able to
# execute return and we are being sourced. Otherwise we aren't allowed to run
# return and we must have been called directly
if ! (return 0 2>/dev/null); then

  if [[ -z "${BUILD_REGISTRY_URL+0}" ]] || [[ -z "${BASE_IMAGE+0}" ]] || [[ -z "${OUTPUT_DIR+0}" ]]; then
    echo "Required parameters not set"
    usage
    exit 1
  fi

  # Verbose output
  set -x
  setup_container
fi
