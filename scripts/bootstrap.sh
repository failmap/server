#!/usr/bin/env bash

# install/update all dependencies for provisioning

if ! test "$(whoami)" == "root";then
  echo "Must run as root or using sudo!"
  exit 1
fi

# determine if this version of bootstrap configuration has already been applied
bootstrap_hash_file="/.bootstrap_$(md5sum "$0" | awk '{print $1}')"
test -f "$bootstrap_hash_file" && exit 0

# log bash trace output to stdout to keep vagrant output green
exec 19>&1
BASH_XTRACEFD=19

function apt-get-install {
  if ! test -f /var/log/apt/history.log;then apt-get -qq update >/dev/null;fi
  DEBIAN_FRONTEND=noninteractive apt-get install -yqq "$@" >/dev/null
}

# propagate command errors, print commands before executing
set -xe

# don't ask for passwords to sudo anymore
mkdir -p /etc/sudoers.d/
echo "%sudo   ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10_sudo
chmod 0440 /etc/sudoers.d/10_sudo

test -x /usr/bin/lsb_release || apt-get-install lsb-release
release=$(/usr/bin/lsb_release -sc)
if test "$release" == "bionic"; then
  release=xenial
fi

if ! command -v curl; then
 apt-get-install curl
fi
curl -s "http://apt.puppetlabs.com/puppetlabs-release-pc1-${release}.deb" \
  -o "puppetlabs-release-pc1-${release}.deb"
dpkg -i "puppetlabs-release-pc1-${release}.deb"
# force update after adding new repository
apt-get -qq update

# install puppet and some dependencies
apt-get-install puppet-agent rsync apt-transport-https git ruby pwgen
# used to install puppet modules using Puppetfile
gem install -q librarian-puppet
# dependencies for some puppet modules (telegraf, consul), TODO: find out why they are not installed automatically
/opt/puppetlabs/puppet/bin/gem install -q toml-rb:1.1.2 curl
rm -f "puppetlabs-release-pc1-${release}.deb"

# remember bootstrap has run
touch "$bootstrap_hash_file"
