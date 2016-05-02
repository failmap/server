#!/usr/bin/env bash

set -e

host=$1
shift

sync=(hiera keys manifests modules scripts hiera.yaml vendor)

rsync -v -a --delete --exclude .git --exclude spec \
  "${sync[@]}" "${host}:provision/"

# shellcheck disable=SC2029
ssh "${host}" sudo provision/scripts/apply.sh "$@"
