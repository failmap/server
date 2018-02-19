#!/usr/bin/env bash

set -e

host=$1
shift

sync=(hiera manifests modules scripts keys hiera.yaml vendor)

rsync -v -a --delete --no-motd \
  --include 'vendor/modules/*/hiera.yaml' \
  --include 'vendor/modules/*/data/' \
  --include 'vendor/modules/*/files/' \
  --include 'vendor/modules/*/lib/' \
  --include 'vendor/modules/*/types/' \
  --include 'vendor/modules/*/manifests/' \
  --include 'vendor/modules/*/templates/' \
  --exclude 'vendor/*/*/*' \
  "${sync[@]}" "$host:provision/"

if test -z "$DEBUG";then
  # shellcheck disable=SC2029
  ssh "$host" sudo -i "FACTER_env=hosted IGNORE_WARNINGS=1 \$PWD/provision/scripts/apply.sh" "$@"
else
  # shellcheck disable=SC2029
  ssh "$host" sudo -i "FACTER_env=hosted \$PWD/provision/scripts/apply.sh" "$@"
fi
