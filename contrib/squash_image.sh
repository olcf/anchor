#!/bin/bash
#
# Pull an image from granite and squash it only using buildah. Push squashed
# image back to granite registry. Final image only has image.sqsh and the boot
# direrctory populated
#
# Read the following vars in from environment
#
# PUPPET_BRANCH, ADDITIONAL_PACKAGES, PXE_OPTIONS, MGMT_SERVER_NAME,
# IMAGE_SUFFIX, CLUSTER_NAME, PUPPET_ROLE, MESSAGE, AUTH_FILE, S3_SERVER,
# S3_ACCESS_ID, S3_ACCESS_KEY
#
# Reads in input images in the following format
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}
#
# Outputs images in the following format
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}

# Debugging flag
set -x
# We use pipes and sometimes they break. Exit on pipe failures
set -o pipefail

# Get puppet commit sha from most recent image
PUPPET_COMMIT_SHA=$(skopeo inspect --authfile "${AUTH_FILE}" \
  "docker://registry.example.com/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}" \
  | grep "puppet_commit" | tr -d '\" ' | cut -d':' -f 2) &&

# Pull client image
container=$(buildah from --authfile "${AUTH_FILE}" \
  "docker://registry.example.com/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}") &&

# Mount it
mount_location=$(buildah mount "${container}") &&

# Add resolv.conf
cp ./image_resolv.conf "${mount_location}"/etc/resolv.conf &&

# Squash it
squash_image=$(mktemp -u) &&
mksquashfs "${mount_location}" "${squash_image}" &&

# Something for minio
echo "mc config host add image-store ${S3_SERVER} ${S3_ACCESS_ID} ${S3_ACCESS_KEY}" &&
echo "mc cp ${squash_image} image-store/${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}" &&

# Cleanup
buildah rm "${container}" &&
buildah rmi \
  "registry.example.com/example-namespace/${PUPPET_ROLE}:${IMAGE_SUFFIX}" &&
rm "${squash_image}"
