#!/bin/sh
#
# Mount an NFS share, copy files needed, unmount. Uses the dracut nfs module.
#
# Reads in the following from the passed environment
#   * $nfs_mount: NFS mount name. Follows the dracut-95nfs module syntax,
#       nfs[4]:<server>:/<path>[:<options>|,<options>]
#   * $nfs_files: Comma separated list of files to copy. [<src>:<dst>,]. Src is
#     relative to the nfs mount, dst is in the initrd
#

# Source dracut module functions
. /lib/nfs-lib.sh

nfs_mount_copy() {
  info "anchor_nfs: Mounting $nfs_mount"

  # Make tmp nfs mount point
  TMP_NFS_MOUNT=/nfs_tmp
  mkdir -m 0755 "$TMP_NFS_MOUNT" &&
  mount_nfs "$nfs_mount" "$TMP_NFS_MOUNT" || \
    die "anchor_nfs: Failed to mount $nfs_mount!"

  # Copy over files
  for file in $(echo "$nfs_files" | sed "s/,/ /g"); do
    src=$(echo "$file" | cut -d ':' -f 1); SRC_PATH="$TMP_NFS_MOUNT/$src"
    dst=$(echo "$file" | cut -d ':' -f 2)
    info "anchor_nfs: Copying file $src from $nfs_mount"
    [ ! -f "$SRC_PATH" ] && \
      die "anchor_nfs: File at $SRC_PATH not found!"
    rsync -hvz --progress "$SRC_PATH" "$dst"
  done

  # Unmount nfs dir
  umount $TMP_NFS_MOUNT
}
