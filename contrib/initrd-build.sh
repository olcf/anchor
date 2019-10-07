#!/bin/bash

# Installing yum repos
cat > /etc/yum.repos.d/os.repo << EOF
[os]
name = os
baseurl = http://mirror.example.com/upstream/rhel/7/x86_64/os/
EOF
cat > /etc/yum.repos.d/anchor.repo << EOF
[anchor]
name = anchor
baseurl = http://mirror.example.com/custom/anchor/el7-x86_64
gpgcheck = 0
EOF

# Install kernel
echo -e "Installing kernel"
yum install -y kernel kernel-devel microcode_ctl linux-firmware

# Install binaries
echo -e "Installing needed binaries"
yum install -y lego dropbear-static buildah-static squashfs-tools-static

# Install dracut modules
echo -e "Installing dracut modules"
yum install -y dracut-network anchor-dracut-module

mkdir -p /output/

KERNEL_PATH=/boot/
KERNEL_PATTERN='vmlinuz-'
# Get the most recent kernel available
KERNEL=$(find "${KERNEL_PATH}" -name "${KERNEL_PATTERN}*" -printf '%f\n' | sort -nr | head -n 1 | sed "s/${KERNEL_PATTERN}//")
# Use user option if it is set
if [ ! -z "${KERNEL_SPECIFIED_VALUE}" ]; then
  USER_KERNEL=${KERNEL_SPECIFIED_VALUE}
  if [ ! -a "/${KERNEL_PATH}/${KERNEL}" ]; then
    echo -e "${RED}Kernel requested ${USER_KERNEL} doesn't exist in ${KERNEL_PATH}! Using ${KERNEL}.${RESTORE}"
  else
    KERNEL=USER_KERNEL
  fi
fi
cp "/${KERNEL_PATH}/${KERNEL_PATTERN}${KERNEL}" /output

echo -e "Probing overlay, squashfs, and loop..."
modprobe overlay squashfs loop mlx4_core mlx4_en mlx4_ib igb bnx2 i40e ipmi_si ipmi_devintf ipmi_msghandler
# Try and force no-hostonly
echo "hostonly=no" >> /etc/dracut.conf

# Build initrd
# Force install drivers, modules we want, and no hostonly to build generic image
echo -e "Making initrd..."
dracut -f -m 'kernel-modules anchor network base' --strip -v \
  --no-hostonly --force-drivers \
  "overlay squashfs loop mlx4_core mlx4_en mlx4_ib igb bnx2 i40e ipmi_si ipmi_devintf ipmi_msghandler amd_microcode" \
  "/output/initrd-${KERNEL}" "${KERNEL}"

chmod 655 "/output/initrd-${KERNEL}"
