#!/usr/bin/env bash

cd "$(dirname "$0")/.." || exit

# perform some sanity checks
if test -z "$(find code/puppet/vendor/modules -mindepth 1)"; then
  echo "No vendor modules found in 'code/puppet/vendor/modules', can't continue!"
  exit 1
fi

# ensure secret random seed is present on the host
mkdir -p /var/lib/puppet/
seedfile=/var/lib/puppet/.random_seed
test -f "$seedfile" || \
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64 > "$seedfile"

if ! test -z "$IGNORE_WARNINGS";then
  # errors/warnings to suppress as they often lead to red herrings.
  ignore='Warning:.*collect exported resources.*nginx/manifests/resource/upstream.pp|Info: Loading facts|Warning:.*(Skipping unparsable iptables rule.*br-|is deprecated)|file & line not available|/vendor/modules/.*(deprecation|collect_exported)|validate_legacy.*/vendor'
  echo "Ignoring Puppet catalog compiler warnings (deprecations, etc)! Disable this with: env DEBUG=1 make deploy"
  ignore_filter="egrep --line-buffered -v '$ignore'"
else
  echo "Showing Puppet catalog compiler warnings (deprecations, etc)."
  ignore_filter=cat
fi

puppet apply \
  --detailed-exitcodes \
  --modulepath=code/puppet/modules:code/puppet/vendor/modules \
  --hiera_config=code/puppet/hiera.yaml \
  --execute "include base" "$@" \
    > >(eval $ignore_filter) \
    2> >(eval $ignore_filter)
# detailed exit code 0 and 2 are considered success.
# https://docs.puppet.com/puppet/4.4/reference/man/apply.html#OPTIONS
e=$?; test $e -eq 2 && exit 0
# all others failure
exit $e
