#!/bin/bash

# foolproof installationscript for failmap

set -e 

git_source=${GIT_SOURCE:-https://gitlab.com/failmap/server.git}

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

if ! grep -E 'Debian GNU/Linux [89]|Ubuntu 18.04' /etc/os-release;then
  echo "OS release not support!"
  cat /etc/os-release
  exit 1
fi

set -v

# cleanup previous attempt if this a retry run of this script
cd /
rm -rf /.bootstrap_* /opt/failmap/server/
mkdir -p /opt/failmap/server/

# install dependencies
apt-get update -qq
apt-get install -yqq git curl 

# get the source
git clone --quiet --branch master "$git_source" /opt/failmap/server/

# install puppet et al
/opt/failmap/server/scripts/bootstrap.sh

# bring to system to the desired state
FACTER_env=hosted IGNORE_WARNINGS=1 /opt/failmap/server/scripts/apply.sh
