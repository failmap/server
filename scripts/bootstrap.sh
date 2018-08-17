#!/usr/bin/env bash

# install/update all dependencies for provisioning

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

# determine if this version of bootstrap configuration has already been applied
bootstrap_hash_file="/.bootstrap_$(md5sum "$0" | awk '{print $1}')"
test -f "$bootstrap_hash_file" && exit 0

# log bash trace output to stdout to keep vagrant output green
exec 19>&1
BASH_XTRACEFD=19

# propagate command errors, print commands before executing
set -xe

# don't ask for passwords to sudo anymore
mkdir -p /etc/sudoers.d/
echo "%sudo   ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10_sudo
chmod 0440 /etc/sudoers.d/10_sudo

test -x /usr/bin/lsb_release || (apt-get -qq update; apt-get install -yqq lsb-release)

release=$(/usr/bin/lsb_release -sc)
if test "$release" == "bionic"; then
  release=xenial
fi

if ! command -v curl; then
  apt-get -qq update
  apt-get install -yqq curl
fi
curl -s "http://apt.puppetlabs.com/puppetlabs-release-pc1-${release}.deb" \
  -o "puppetlabs-release-pc1-${release}.deb"
dpkg -i "puppetlabs-release-pc1-${release}.deb"
apt-get -qq update
# install puppet and some dependencies
apt-get install -yqq puppet-agent rsync apt-transport-https git ruby
# used to install puppet modules using Puppetfile
gem install -q librarian-puppet
# dependencies for some puppet modules (telegraf, consul), find out why they are not installed automatically
/opt/puppetlabs/puppet/bin/gem install -q toml-rb curl
rm -f "puppetlabs-release-pc1-${release}.deb"

# remember bootstrap has run
touch "$bootstrap_hash_file"
