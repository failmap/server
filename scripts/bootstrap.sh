#!/usr/bin/env bash

# install puppet and dependencies

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

set -ve

test -x /usr/bin/lsb_release || (apt-get -q update; apt-get install -yqq lsb-release)

release=$(/usr/bin/lsb_release -sc)

if ! which curl; then
  apt-get -q update
  apt-get install -yqq curl
fi
curl "http://apt.puppetlabs.com/puppetlabs-release-pc1-${release}.deb" \
  -o "puppetlabs-release-pc1-${release}.deb"
dpkg -i "puppetlabs-release-pc1-${release}.deb"
apt-get -q update
apt-get install -yqq puppet rsync apt-transport-https
gem install hiera-eyaml deep_merge hiera highline
rm "puppetlabs-release-pc1-${release}.deb"
