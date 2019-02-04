#!/bin/bash

# pull in upstream changes and apply new configuration

if ! test "$(whoami)" == "root";then
  echo "Must run as root or using sudo!"
  exit 1
fi

set -ex

cd /opt/failmap/server
# pull in latest changed from upstream
git remote update

# force update current working directory to upstream
branch=$(git rev-parse --abbrev-ref HEAD)
git reset --hard "origin/$branch"

# make sure puppet correct modules are installed
(cd code/puppet/; librarian-puppet install)

# apply changes
/opt/failmap/server/scripts/apply.sh "$@"