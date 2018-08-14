#!/bin/bash

set -e 

apt update -q
apt install git -yq
mkdir -p /opt/failmap/server/
git clone https://gitlab.com/failmap/server.git /opt/failmap/server/
/opt/failmap/server/scripts/bootstrap.sh
/opt/failmap/server/scripts/apply.sh
