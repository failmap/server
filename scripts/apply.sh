#!/usr/bin/env bash

cd "$(dirname "$0")/.." || exit

puppet apply \
  --detailed-exitcodes \
  --modulepath=modules:vendor/modules \
  --hiera_config=hiera.yaml \
  manifests/site.pp "$@"
# detailed exit code 0 and 2 are considered success.
# https://docs.puppet.com/puppet/4.4/reference/man/apply.html#OPTIONS
e=$?; test $e -eq 2 && exit 0
# all others failure
exit $e
