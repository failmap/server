#!/usr/bin/env bash

set -e

host=$1
shift

sync=(hiera manifests modules scripts keys hiera.yaml vendor)

rsync -v -a --delete --no-motd \
  --include 'vendor/modules/*/files/' \
  --include 'vendor/modules/*/lib/' \
  --include 'vendor/modules/*/manifests/' \
  --include 'vendor/modules/*/templates/' \
  --exclude 'vendor/*/*/*' \
  "${sync[@]}" "$host:provision/"

# shellcheck disable=SC2029
ssh "$host" sudo -i "\${PWD}/provision/scripts/apply.sh" "$@"
