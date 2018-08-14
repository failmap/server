#!/bin/bash

set -ev

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

if ! grep "Debian GNU/Linux 8" /etc/os-release;then
  echo "OS must be Debian 8"
  exit 1
fi

apt-get update -qq
apt-get install -yqq git curl 
rm -rf /opt/failmap/server/
mkdir -p /opt/failmap/server/
git clone --branch master https://gitlab.com/failmap/server.git /opt/failmap/server/
/opt/failmap/server/scripts/bootstrap.sh
/opt/failmap/server/scripts/apply.sh
