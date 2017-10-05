#!/bin/bash

set -e

sudo apt-get update
sudo apt install -yqq build-essential libssl-dev
wget https://github.com/rbsec/sslscan/archive/1.11.0-rbsec.tar.gz
tar zxf 1.11.0-rbsec.tar.gz
pushd sslscan-1.11.0-rbsec/
make sslscan
sudo install sslscan /usr/local/bin/
popd
