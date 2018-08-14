#!/bin/bash

set -e 

if ! test "$(whoami)" == "root";then
  echo "Must run as root!"
  exit 1
fi

if ! grep "Debian GNU/Linux 8" /etc/os-release;then
  echo "OS must be Debian 8"
  exit 1
fi

apt update -q
apt install git curl -yqq
mkdir -p /opt/failmap/server/
git clone https://gitlab.com/failmap/server.git /opt/failmap/server/
/opt/failmap/server/scripts/bootstrap.sh
/opt/failmap/server/scripts/apply.sh
