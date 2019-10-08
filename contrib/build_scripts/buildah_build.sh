#!/bin/bash
#
# Build a new image only using buildah. Save everything to granite registry.
#
# Read the following vars in from environment
#
# PUPPET_BRANCH, IMAGE_SUFFIX, CLUSTER_NAME, PUPPET_ROLE, MESSAGE, AUTH_FILE,
# BUILD_REGISTRY_URL, BASE_IMAGE
#
# Outputs images in the following format
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}

# Debugging flag
set -x
# We use pipes and sometimes they break. Exit on pipe failures
set -o pipefail

container=$(buildah from --authfile "${AUTH_FILE}" \
  "${BUILD_REGISTRY_URL}/${BASE_IMAGE}") &&

# Add build tools
buildah copy "${container}" build_image/build_image.sh \
  /image-build-tools/build_image.sh &&
buildah copy "${container}" puppet_yum.conf /image-build-tools/yum.conf &&

# Add puppet keys
buildah copy "${container}" \
  "/etc/images/puppet_keys/certs/${CLUSTER_NAME}_shared.pem" \
  "/etc/puppetlabs/puppet/ssl/certs/${CLUSTER_NAME}_shared.pem" &&
buildah copy "${container}" \
  "/etc/images/puppet_keys/private_keys/${CLUSTER_NAME}_shared.pem" \
  "/etc/puppetlabs/puppet/ssl/private_keys/${CLUSTER_NAME}_shared.pem" &&
buildah copy "${container}" \
  "/etc/images/puppet_keys/public_keys/${CLUSTER_NAME}_shared.pem" \
  "/etc/puppetlabs/puppet/ssl/public_keys/${CLUSTER_NAME}_shared.pem" &&

# Install puppet
buildah run "${container}" \
  yum install -c /image-build-tools/yum.conf -y puppet &&

# Set facts, run puppet, build dracut initrd
buildah config --env PUPPET_BRANCH="${PUPPET_BRANCH}" "${container}" &&
buildah config --env IMAGE_SUFFIX="${IMAGE_SUFFIX}" "${container}" &&
buildah config --env CLUSTER_NAME="${CLUSTER_NAME}" "${container}" &&
buildah config --env PUPPET_ROLE="${PUPPET_ROLE}" "${container}" &&
buildah config --env MESSAGE="${MESSAGE}" "${container}" &&
buildah run "${container}" bash -c \
  "/image-build-tools/build_image.sh" | tee /tmp/build_output.log &&

# Copy resolv.conf into the image
buildah copy "${container}" image_resolv.conf /etc/resolv.conf &&

# Get puppet version image built with
PUPPET_COMMIT_SHA=$(grep -oP -m 1 \
  "Info: Applying configuration version \'\K\w+(?=')" \
  /tmp/build_output.log) &&

# Add helpful labels
buildah config \
  --label build_reason="${MESSAGE}" \
  --label puppet_branch="${PUPPET_BRANCH}" \
  --label mantainer="${GITLAB_USER_NAME}" \
  --label puppet_commit="${PUPPET_COMMIT_SHA}" \
  "${container}" &&

container_mount=$(buildah mount "${container}") &&

# Store image info in file
cat <<-EOF > "${container_mount}/${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA:-000000}" &&
BUILD_REASON="${MESSAGE}"
PUPPET_BRANCH="${PUPPET_BRANCH}"
MANTAINER="${GITLAB_USER_NAME}"
PUPPET_COMMIT="${PUPPET_COMMIT_SHA}"
PUPPET_BRANCH="${PUPPET_BRANCH}"
IMAGE_SUFFIX="${IMAGE_SUFFIX}"
CLUSTER_NAME="${CLUSTER_NAME}"
PUPPET_ROLE="${PUPPET_ROLE}"
MESSAGE="${MESSAGE}"
EOF

buildah umount "${container}" &&

# Push new image
buildah commit --authfile "${AUTH_FILE}" "${container}" \
  "docker://${BUILD_REGISTRY_URL}/${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA:-000000}" &&

# Cleanup
buildah rm "${container}"
# Try to delete base image, but could fail because the build host has other
# images that are dependent on it
buildah rmi "${BUILD_REGISTRY_URL}/${BASE_IMAGE}" || true
