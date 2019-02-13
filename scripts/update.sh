#!/bin/bash

# pull in upstream changes and apply new configuration

if ! test "$(whoami)" == "root";then
  echo "Must run as root or using sudo!"
  exit 1
fi

set -e

cd /opt/websecmap/server
# pull in latest changed from upstream
git remote update

branch=$(git rev-parse --abbrev-ref HEAD)

echo
echo "The following changes will be applied:"
git log --pretty="format: - %s" "$branch...origin/$branch"
echo

# force update current working directory to upstream
git reset --hard "origin/$branch"

# make sure puppet correct modules are installed
(cd code/puppet/; librarian-puppet install)

# apply changes
/opt/websecmap/server/scripts/apply.sh "$@"
