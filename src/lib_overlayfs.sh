#!/bin/sh
#
# Mount an overlay filesystem on top of the existing NEWROOT mount
#
# Moves existing sysroot to a new mount point. Creates a ramdisk on another
# mount point. Copy over all writable directories to the ramdisk. Make an
# overlay filesystem from the existing sysroot and the new ramdisk.
#
# Reads in the following from passed environment
#   * $NEWROOT:             New root to switch to in dracut. Believe it's
#                           hardcoded in the 99base module
#   * $overlayfs_size:      Size to make the local ramdisk. Set in the boot
#                           command line, parsed by writable-parser.sh
#   * $overlayfs_write:     Comma separated list of directories to make
#                           writable. Can be subdirectories or even /

overlayfs_create() {
  info "Trying to mount overlayfs..."
  TMP_OVERLAY_MOUNTPOINT=/overlayfs_tmp

  # Make writable mount on temp dir
  mkdir "$TMP_OVERLAY_MOUNTPOINT"
  mount -n -t tmpfs -o "mode=755,size=$overlayfs_size" none "$TMP_OVERLAY_MOUNTPOINT"

  write_array=$(echo "${overlayfs_write}" | tr ',' ' ')
  for write_dir in ${write_array}; do
    # Add directories for overlayfs
    mkdir -p "$TMP_OVERLAY_MOUNTPOINT/$write_dir/"
    mkdir "$TMP_OVERLAY_MOUNTPOINT/$write_dir/upper"
    mkdir "$TMP_OVERLAY_MOUNTPOINT/$write_dir/work"
    # Copy over directory structure
    rsync -a --include '*/' --exclude '*' "$NEWROOT/$write_dir/" "$TMP_OVERLAY_MOUNTPOINT/$write_dir/upper/"

    # Mount overlay
    mount -n -t overlay -o "lowerdir=$NEWROOT/$write_dir,upperdir=$TMP_OVERLAY_MOUNTPOINT/$write_dir/upper,workdir=$TMP_OVERLAY_MOUNTPOINT/$write_dir/work" overlay "$NEWROOT"/"$write_dir" && \
    info "Mounted overlay filesystem for $write_dir"
  done

  # Add upper to sysroot/mnt to make visable
  # Makes writable directory available to booted system. Can check `df` to see
  # if overlayfs is filled without needing this bind mount. Bind mount provides
  # file granularity
  mkdir "$NEWROOT"/mnt/overlay_writable
  mount --bind -o ro "$TMP_OVERLAY_MOUNTPOINT"/ "$NEWROOT"/mnt/overlay_writable

  # Cleanup
  umount "$TMP_OVERLAY_MOUNTPOINT"
  rm -r "$TMP_OVERLAY_MOUNTPOINT"

}
