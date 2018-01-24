#!/usr/bin/env bash

cd "$(dirname "$0")/.." || exit

# ensure secret random seed is present on the host
mkdir -p /var/lib/puppet/
seedfile=/var/lib/puppet/.random_seed
test -f "$seedfile" || \
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64 > "$seedfile"

# errors/warnings to suppress as they only lead to red herrings.
ignore='Warning:.*collect exported resources.*nginx/manifests/resource/upstream.pp|Info: Loading facts'

puppet apply \
  --detailed-exitcodes \
  --modulepath=modules:vendor/modules \
  --hiera_config=hiera.yaml \
  manifests/site.pp "$@" \
    > >(egrep --line-buffered -v "$ignore") \
    2> >(egrep --line-buffered -v "$ignore")
# detailed exit code 0 and 2 are considered success.
# https://docs.puppet.com/puppet/4.4/reference/man/apply.html#OPTIONS
e=$?; test $e -eq 2 && exit 0
# all others failure
exit $e
