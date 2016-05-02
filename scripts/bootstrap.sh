#!/usr/bin/env bash

# install puppet and dependencies

set -ve

release=$(lsb_release -sc)

if ! which curl; then
  sudo apt-get -q update
  sudo apt-get install -yqq curl
fi
curl "http://apt.puppetlabs.com/puppetlabs-release-pc1-${release}.deb" \
  -o "puppetlabs-release-pc1-${release}.deb"
sudo dpkg -i "puppetlabs-release-pc1-${release}.deb"
sudo apt-get -q update
sudo apt-get install -yqq puppet rsync
sudo gem install hiera-eyaml deep_merge hiera highline
rm "puppetlabs-release-pc1-${release}.deb"
