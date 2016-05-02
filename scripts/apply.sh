#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/.."

which puppet >/dev/null || ./scripts/bootstrap.sh

puppet apply \
  --modulepath=modules:vendor/modules \
  --hiera_config=hiera.yaml \
  manifests/site.pp "$@" 2>&1| grep -v 'parameter to concat::fragment is deprecated and has no effect'
