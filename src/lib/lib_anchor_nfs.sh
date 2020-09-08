#!/bin/sh
#
# Mount an NFS share, copy the compressed image. Uses the lib_nfs library from
# dracut nfs module.
#
# Reads in the following from the passed environment
#   * $nfs_mount: NFS mount name. Follows the dracut-95nfs module syntax,
#       nfs[4]:<server>:/<path>[:<options>|,<options>]
#   * $nfs_image_path: Path to image to copy, relative to nfs_mount path
#

# Source dracut module functions
. /lib/lib_nfs.sh

# Mount share, copy image to dracut ramdisk
nfs_mount() {
  info "anchor_nfs: Mounting $nfs_mount"

  # Make tmp nfs mount point
  TMP_NFS_MOUNT=/nfs_tmp
  mkdir -m 0755 "$TMP_NFS_MOUNT"
  mount_nfs $nfs_root $TMP_NFS_MOUNT || \
    die "anchor_nfs: Failed to mount $nfs_root!"

  # Make tmpfs mount for the squashfs image to be stored locally
  TMP_SQUASH_RAMDISK=/squashfs_tmp
  mkdir -m 0755 "$TMP_SQUASH_RAMDISK"

  # Copy over squashfs image
  info "anchor_nfs: Copying image from $nfs_image_path"
  IMAGE_PATH="$TMP_NFS_MOUNT/$nfs_image_path"
  [ ! -f "$IMAGE_PATH" ] && \
    die "anchor_nfs: Image at $IMAGE_PATH not found!"
  rsync -hvz --progress "$IMAGE_PATH" "$TMP_SQUASH_RAMDISK"/image.sqsh

  # Unmount nfs dir
  umount $TMP_NFS_MOUNT

  # Move image ramdisk inside newroot
  mount --bind "$TMP_SQUASH_RAMDISK"/ "$NEWROOT"
}
