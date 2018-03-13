#!/usr/bin/env bash

set -e

host=$1
shift

ssh "$host" mkdir -p provision/

rsync -v -a --delete --no-motd \
  'scripts' \
  'configuration' \
  'code' \
  --exclude '.*' \
  --include 'code/puppet/vendor/modules/*/hiera.yaml' \
  --include 'code/puppet/vendor/modules/*/data/' \
  --include 'code/puppet/vendor/modules/*/files/' \
  --include 'code/puppet/vendor/modules/*/lib/' \
  --include 'code/puppet/vendor/modules/*/types/' \
  --include 'code/puppet/vendor/modules/*/manifests/' \
  --include 'code/puppet/vendor/modules/*/templates/' \
  --exclude 'code/puppet/vendor/*/*/*' \
  "$host:provision/"

if test -z "$DEBUG";then
  # shellcheck disable=SC2029
  ssh "$host" sudo -i "FACTER_env=hosted IGNORE_WARNINGS=1 \$PWD/provision/scripts/apply.sh" "$@"
else
  # shellcheck disable=SC2029
  ssh "$host" sudo -i "FACTER_env=hosted \$PWD/provision/scripts/apply.sh" "$@"
fi
