#!/bin/bash

# pull in upstream changes and apply new configuration

set -e

if ! test "$(whoami)" == "root";then
  echo "Must run as root or using sudo!"
  exit 1
fi

cd /opt/failmap/server
# pull in latest changed from upstream
git remote update
# for to update current working directory to upstream
branch=$(git rev-parse --abbrev-ref HEAD)
git reset --hard "origin/$branch"

# apply changes
/opt/failmap/server/scripts/apply.sh