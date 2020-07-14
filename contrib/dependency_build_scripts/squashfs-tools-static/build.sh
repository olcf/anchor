#!/bin/bash

echo "Starting..."

PATH="${PATH}:/var/lib/jenkins/bin"

package="squashfs-tools-static"
krelease=$(uname -r)
url='https://github.com/plougher/squashfs-tools/'
rpmdist="el7" # building for rhel7 by default
version="4.3"
rpm_release="1"

if [[ "${krelease}" == *.el6.* ]]; then
  rpmdist="el6";
fi

mkdir -p "$(_get_artifacts_dir)"
sudo yum -y install bash rpm ruby ruby-devel rubygems gem gcc redhat-lsb-core
gem install --user-install fpm

sudo yum -y install glibc-static zlib-static git make gcc

git clone "${url}"
cd ./squashfs-tools
cd ./squashfs-tools
LDFLAGS="-static" make

fpm --architecture x86_64 \
    -s dir \
    -t rpm \
    -n "${package}" \
    --url "$url" \
    --rpm-dist "${rpmdist}" \
    --version "${version}" \
    --iteration "${rpm_release}" \
    "$(pwd)/mksquashfs=/usr/bin/mksquashfs.static" \
    "$(pwd)/unsquashfs=/usr/bin/unsquashfs.static"

cp ./*.rpm "$(_get_artifacts_dir)"

rpm_destinations jenkins-built-for-testing
