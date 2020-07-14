#!/bin/bash

echo "Starting..."

PATH="${PATH}:/var/lib/jenkins/bin"

package="dropbear-static"
krelease=$(uname -r)
url='https://matt.ucc.asn.au/dropbear/dropbear.html'
rpmdist="el7" # building for rhel7 by default
version="2019.78"
rpm_release="1"

if [[ "${krelease}" == *.el6.* ]]; then
  rpmdist="el6";
fi

START_DIR=$(pwd)
mkdir -p "${START_DIR}/artifacts"

wget "https://matt.ucc.asn.au/dropbear/releases/dropbear-${version}.tar.bz2"
tar xvf "dropbear-${version}.tar.bz2"
cd "dropbear-${version}"

./configure --prefix=/ --disable-zlib --enable-static
make

fpm --architecture x86_64 \
    -s dir \
    -t rpm \
    -n "${package}" \
    --url "$url" \
    --rpm-dist "${rpmdist}" \
    --version "${version}" \
    --iteration "${rpm_release}" \
    "$(pwd)/dropbear=/usr/bin/"

ls -l

cp ./*.rpm "${START_DIR}/artifacts/"

ls -l "${START_DIR}/artifacts"
