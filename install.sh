#!/bin/bash

# foolproof installationscript for failmap

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

if ! grep "Debian GNU/Linux 8" /etc/os-release >/dev/null;then
  echo "OS must be Debian 8"
  exit 1
fi

cd ~

set -ev

# cleanup previous attempt if this a retry run of this script
rm -rf /.bootstrap_* /opt/failmap/server/
mkdir -p /opt/failmap/server/

# install dependencies
apt-get update -qq
apt-get install -yqq git curl 

# get the source
git clone --quiet --branch master https://gitlab.com/failmap/server.git /opt/failmap/server/

# install puppet et al
/opt/failmap/server/scripts/bootstrap.sh

# bring to system to the desired state
FACTER_env=hosted IGNORE_WARNINGS=1 /opt/failmap/server/scripts/apply.sh
