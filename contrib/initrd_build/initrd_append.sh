#!/bin/bash
#
# Append a file to the gzipped initrd cpio
#

usage() {
  echo "Usage: $0 [-h|--help] <FILE_TO_ADD> <INITRD_TO_ADD_TO>"
}

if [[ "${1}" =~ (-h|--help) ]]; then
  usage
  exit 1
fi

FILE_TO_ADD="${1}"
INITRD_PATH="${2}"

if ! [[ -f "${FILE_TO_ADD}" ]]; then
  echo "File: $FILE_TO_ADD is not a file"
  usage
  exit 1
fi
if ! [[ -f "${INITRD_PATH}" ]]; then
  echo "Initrd: $INITRD_PATH is not a file"
  usage
  exit 1
fi

cur_dir=$(pwd); tmp_dir=$(mktemp -d);
cp "${FILE_TO_ADD}" "${tmp_dir}"
cp "${INITRD_PATH}" "${tmp_dir}"
cd "${tmp_dir}"

new_file_basename=$(basename "${FILE_TO_ADD}")
# Install early cpio files
echo "Extracting early CPIO"
cpio -i < "${INITRD_PATH}"
echo "Building early CPIO"
# Build early cpio from installed files
cpio -t < "${INITRD_PATH}" | cpio -oc > initrd
echo "Unzipping main CPIO"
# Unzip initrd cpio archive
/usr/lib/dracut/skipcpio "${INITRD_PATH}" | zcat > initrd.cpio
# Append new file to cpio, compress
echo "Appending new file to main CPIO"
echo "${new_file_basename}" | cpio -ocAO initrd.cpio
echo "Compressing initrd"
gzip -9 < initrd.cpio >> initrd
cd "${cur_dir}"
mv "${tmp_dir}/initrd" "${INITRD_PATH}"
echo "Cleaning"
rm -rf "${tmp_dir}"
