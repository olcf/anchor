#!/bin/bash

echo "Starting..."

PATH="${PATH}:/var/lib/jenkins/bin"

package="lego"
krelease=$(uname -r)
url='https://github.com/go-acme/lego'
rpmdist="el7" # building for rhel7 by default
version="v2.6.0"
rpm_release="1"

if [[ "${krelease}" == *.el6.* ]]; then
  rpmdist="el6";
fi

mkdir -p "$(_get_artifacts_dir)"
sudo yum -y install bash rpm ruby ruby-devel rubygems gem gcc redhat-lsb-core
sudo yum install -y golang make rpm-build git
gem install --user-install fpm

export GOPATH="$(pwd)/go"
git clone "$url" "$GOPATH/src/github.com/go-acme/lego"
cd "$_"
git checkout "$version"
make build


fpm --architecture x86_64 \
    -s dir \
    -t rpm \
    -n "${package}" \
    --url "$url" \
    --rpm-dist "${rpmdist}" \
    --version "${version}" \
    --iteration "${rpm_release}" \
    "$(pwd)"/dist/lego=/usr/bin/

cp ./*.rpm "$(_get_artifacts_dir)"

rpm_destinations jenkins-built-for-testing
