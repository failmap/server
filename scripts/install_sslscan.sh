#!/bin/bash

# determine if this version of script has already been applied
bootstrap_hash_file="/.bootstrap_$(md5sum "$0" | awk '{print $1}')"
test -f "$bootstrap_hash_file" && exit 0

set -e

apt-get update
apt-get install -yqq build-essential libssl-dev
wget https://github.com/rbsec/sslscan/archive/1.11.0-rbsec.tar.gz
tar zxf 1.11.0-rbsec.tar.gz
pushd sslscan-1.11.0-rbsec/
make sslscan
install sslscan /usr/local/bin/
popd

# remember bootstrap has run
touch "$bootstrap_hash_file"
