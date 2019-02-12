#!/bin/bash

# foolproof installation script for failmap

set -e

git_source=${GIT_SOURCE:-https://gitlab.com/internet-cleanup-foundation/server/}
git_branch=${GIT_BRANCH:-master}
configuration=${FAILMAP_CONFIGURATION}

n="\\e[39m"
b="\\e[1m"
y="\\e[33m"

echo -e "${b}Welcome to Failmap installation.${n}"
echo
echo 'For help please visit: https://gitlab.com/internet-cleanup-foundation/server/blob/master/documentation/hosting.md'
echo
echo -e "${y}Warning: this installation script assumes to be run on a fresh installed OS and _will_ make changes to this server's OS. Press [ctrl-c] at any time to abort.${n}"

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

if ! grep -E 'Debian GNU/Linux [89]|Ubuntu 18.04' /etc/os-release >/dev/null;then
  echo "Error: this OS/release is not support!"
  cat /etc/os-release
  exit 1
fi

if test -d /opt/failmap/;then
  set -v
  # cleaning up previous attempt
  cd /
  rm -rf /.bootstrap_* /opt/failmap/
fi
set -v

# installing dependencies
apt-get update -qq >/dev/null
apt-get install -yqq git >/dev/null

# getting the source
git clone --quiet --branch "$git_branch" "$git_source" /opt/failmap/server/

if ! test -z "$configuration"; then
    echo "$configuration" >> /opt/failmap/server/configuration/settings.yaml
fi

# installing configuration management dependencies
/opt/failmap/server/scripts/bootstrap.sh

# bringing the system in the desired state
/opt/failmap/server/scripts/apply.sh

cat /etc/motd
