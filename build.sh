#!/bin/bash
#

url='https://github.com/olcf/anchor'
rhel_version="$(cat /etc/redhat-release)"
if [[ $rhel_version = *"Maipo"* ]]; then
  rpm_dist="el7"
elif [[ $rhel_version = *"Santiago"* ]]; then
  rpm_dist="el6"
fi

package_name="anchor-dracut-module"
description="Dracut module to boot into anchor"
version="$(git describe --tags --abbrev=0)"
iteration="$(git rev-parse --short HEAD)"

echo "Running build"

cd ./src
fpm --architecture all \
  -s dir \
  -t rpm \
  -n "$package_name" \
  --url "$url" \
  --description "$description" \
  --version "$version" \
  --iteration "$iteration" \
  --rpm-user "root" \
  --rpm-group "root" \
  --rpm-os "linux" \
  --rpm-defattrfile 0755 \
  --rpm-dist "$rpm_dist" \
  --verbose \
  ./=/usr/lib/dracut/modules.d/50anchor

mv ./*.rpm ../
