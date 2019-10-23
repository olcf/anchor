#!/bin/bash
#
# Pull an image from granite and squash it only using buildah. Push squashed
# image back to granite registry. Final image only has image.sqsh and the boot
# direrctory populated
#
# Read the following vars in from environment
#
# IMAGE_NAME, AUTH_FILE, S3_SERVER, S3_ACCESS_ID, S3_ACCESS_KEY_FILE
#
# Reads in/outputs images in the following format
# ${PUPPET_ROLE}:${IMAGE_SUFFIX}-${CI_SHORT_SHA}-${PUPPET_COMMIT_SHA}

usage() {
  echo "Usage: $0 --image-name <> --auth-file <> --s3-server <> --s3-id <> --s3-key <> -h"
}

while true; do
  case "$i" in
    --image-name)
      IMAGE_NAME=$2
      shift 2
      ;;
    --auth-file)
      AUTH_FILE=$2
      shift 2
      ;;
    --s3-server)
      S3_SERVER=$2
      shift 2
      ;;
    --s3-id)
      S3_ACCESS_ID=$2
      shift 2
      ;;
    --s3-key-file)
      S3_ACCESS_KEY_FILE=$2
      shift 2
      ;;
    -h)
      usage
      exit 1
      ;;
    --)
      shift
      break
      ;;
  esac
done

# Debugging flag
set -x
# We use pipes and sometimes they break. Exit on pipe failures
set -o pipefail

# Pull client image
container=$(buildah from --authfile "${AUTH_FILE}" \
  "docker://registry.example.com/example-namespace/${IMAGE_NAME}") &&

# Mount it
mount_location=$(buildah mount "${container}") &&

# Add resolv.conf
cp ./image_resolv.conf "${mount_location}"/etc/resolv.conf &&

# Squash it
squash_image=$(mktemp -u) &&
mksquashfs "${mount_location}" "${squash_image}" &&

# Copy image to minio
mc config host add image-store "${S3_SERVER}" "${S3_ACCESS_ID}" "${S3_ACCESS_KEY}" &&
mc cp "${squash_image}" "image-store/${IMAGE_NAME}" &&

# Cleanup
buildah rm "${container}" &&
buildah rmi \
  "registry.example.com/example-namespace/${IMAGE_NAME}" &&
rm "${squash_image}"
