#!/bin/sh
#
# Use a squashfs filesystem as the system root. Will either copy squashed image
# to a local ramdisk, create a new squashfs, or use the image from a mounted
# filesystem.
#
# Reads in the following from the passed environment
#   * $squashfs_curl:   Copy image to local ramdisk using curl
#   * $squashfs_rsync:  Copy image to local ramdisk using rsync
#   * $squashfs_server: URL to get image from
#   * $squashfs_create_path: Create a new squashfs from this path
#
# Uses /ca.pem as the CA for curl, and client.{key,cert} for mutual tls

# Copy squashfs image to dracut ramdisk
squashfs_copy_image() {
  info "squashfs: Copying squash image to local ramdisk"
  TMP_SQUASH_RAMDISK=/squashfs_tmp

  # Make tmpfs mount for the squashfs image to be stored locally
  mkdir -m 0755 "$TMP_SQUASH_RAMDISK"

  # Copy over squashfs image
  if [ "${squashfs_curl:-0}" -eq 1 ]; then

    # Need randomness to curl
    while true; do
      read entropy_avail < /proc/sys/kernel/random/entropy_avail
      read read_wakeup_threshold < /proc/sys/kernel/random/read_wakeup_threshold
      # shellcheck disable=SC2086
      if [ $entropy_avail -gt $read_wakeup_threshold ]; then
        break
      else
        sleep 1
      fi
    done

    curl --cacert /ca.pem --key /client.key --cert /client.cert \
      -o "$TMP_SQUASH_RAMDISK"/image.sqsh "$squashfs_server"
  elif [ "${squashfs_rsync:-0}" -eq 1 ]; then
    rsync -hvz --progress "$squashfs_server" "$TMP_SQUASH_RAMDISK"/image.sqsh
  else
    info "squashfs: Error! Neither squashfs_curl or squashfs_rsync specified. No way to run copy_squashfs_image"
    exit 1
  fi

  # Move image ramdisk inside newroot
  mount --bind "$TMP_SQUASH_RAMDISK"/ "$NEWROOT"
}

squashfs_mount() {
  modprobe loop

  # Mount squash
  mount -t squashfs -o loop "$NEWROOT"/image.sqsh "$NEWROOT" && \
  info "Mounted squashfs filesystem"
}

# Create a squashed filesystem at /image.sqsh
squashfs_create() {
  info "squashfs: Creating squashed image"
  mksquashfs.static "${squashfs_create_path}" "$NEWROOT"/image.sqsh
}
