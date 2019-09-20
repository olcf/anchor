#!/bin/sh
#
# Download and mount an image from a docker registry
#
# Reads in the following from the passed environment
#   * $buildah_registry:  Docker registry to connect to
#   * $buildah_image:     Image to download and mount from registry
#
# Uses the file /ca.pem as the registry's CA, and uses the files /client.cert
# and /client.key as the client's authentication certs
#
# Exports the following to the environment
#   * $buildah_mountpath: Path where the image has been mounted
#

# Install certificates for registry
buildah_install_certificates() {
  mkdir -p /etc/containers/
  mkdir -p /etc/containers/certs.d
  mkdir -p /etc/containers/certs.d/"${buildah_registry}"/
  cp /ca.pem /etc/containers/certs.d/"${buildah_registry}"/ca.crt
  cp /client.cert /etc/containers/certs.d/"${buildah_registry}"/
  cp /client.key /etc/containers/certs.d/"${buildah_registry}"/
}

# Mount as tmpfs /var for container storage, install signature-less policy
buildah_create_storage() {
  # Mount tmpfs in var
  info "buildah: Setting mounts and policy for container storage"
  mount -t tmpfs none /var
  mkdir -p /var/tmp

  # Install security policy
  mkdir -p /etc/containers/
  echo '{"default":[{"type":"insecureAcceptAnything"}]}' \
    > /etc/containers/policy.json
}

# Delete containers and container storage
buildah_cleanup() {
  info "buildah: Removing container storage"
  buildah.static rm -a
  umount /var/
}

# Pull image from registry, mount filesystem
buildah_mount_image() {
  # Pull image from registry
  info "buildah: Pulling image from registry: ${buildah_registry}/${buildah_image}..."
  container=$(buildah.static from "${buildah_registry}/${buildah_image}")

  # Mount image as a read-write container
  info "buildah: Mounting container..."
  mountpath=$(buildah.static mount "${container}")
  export buildah_mountpath=$mountpath
}
