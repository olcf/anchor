#!/bin/bash
#
# Builds a base RedHat image using a core-repository
#
# Reads in the snapshot to build against, the registry to push to, the name
# of the output image, and registry authentication file. Will output a image in
# the registry tagged with the snapshot
#

usage() {
  echo "Usage: $0 [-u|--repo-url <REPO_URL>] [-r|--registry <REGISTRY_URL] [-o|--output <OUTPUT_IMAGE>] [-a|--auth <DOCKER_AUTH_FILE>] [-h|--help]"
}

while test -n "${1}"; do
  case "$1" in
    -u|--repo-url)
      REPO_URL=$2
      shift 2
      ;;
    -r|--registry)
      BUILD_REGISTRY_URL=$2
      shift 2
      ;;
    -o|--output)
      OUTPUT_IMAGE=$2
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

if [[ -z "${BUILD_REGISTRY_URL+0}" ]] || [[ -z "${REPO_URL+0}" ]] || [[ -z "${OUTPUT_IMAGE+0}" ]]; then
  echo "Required parameters not set"
  usage
  exit 1
fi

# Verbose output
set -x

OS_REPO_FILE=$(mktemp -u)

cat > "${OS_REPO_FILE}" <<EOF
[os-core]
name = os-core
enabled = 1
baseurl = ${REPO_URL}
gpgcheck = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF

container=$(buildah from scratch) &&
mount_path=$(buildah mount "$container") &&
yum -c "${OS_REPO_FILE}" --disablerepo=* --enablerepo=os-core install \
  --installroot="$mount_path" -y @base @core &&
yum -c "${OS_REPO_FILE}" --enablerepo=os-core --installroot="$mount_path" \
  clean all &&
buildah commit --authfile "${AUTH_FILE}" "$container" \
  "docker://${BUILD_REGISTRY_URL}/${OUTPUT_IMAGE}" &&
rm -f "${OS_REPO_FILE}" &&
buildah rm "$container"
