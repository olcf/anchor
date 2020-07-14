#!/bin/bash
#
# Pull an image from granite and squash it only using buildah. Push squashed
# image back to granite registry. Final image only has image.sqsh and the boot
# direrctory populated
#
# Squash an image from the registry.
# Read the following vars in from environment
#
# IMAGE_NAME, REGISTRY_URL, AUTH_FILE
#
# Outputs images in the following format
# ${PUPPET_ROLE}_sqsh:${IMAGE_SUFFIX}
# ${PUPPET_ROLE}_sqsh:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}

# Debugging flag
set -x
# We use pipes and sometimes they break. Exit on pipe failures
set -o pipefail

# Get puppet commit sha from most recent image
PUPPET_COMMIT_SHA=$(skopeo inspect --authfile "${AUTH_FILE}" \
  "docker://${BUILD_REGISTRY_URL}/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}" \
  | grep "PUPPET_COMMIT" | tr -d '\" ' | cut -d':' -f 2) &&

# Pull client image
container=$(buildah from --authfile "${AUTH_FILE}" \
  "docker://registry.example.com/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}") &&

# Mount it
mount_location=$(buildah mount "${container}") &&

# Squash it
squash_image=$(mktemp -u) &&
mksquashfs "${mount_location}" "${squash_image}" &&

# Cleanup
buildah umount "${container}" &&
buildah rm "${container}" &&
buildah rmi \
  "registry.example.com/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}" &&
rm "${squash_image}"
