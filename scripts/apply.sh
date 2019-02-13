#!/usr/bin/env bash

# apply puppet configuration

if ! test "$(whoami)" == "root";then
  echo "Must run as root or using sudo!"
  exit 1
fi

cd "$(dirname "$(readlink -f "$0")")/.." || exit

export PATH=/opt/puppetlabs/bin:$PATH
export FACTER_env=${FACTER_env:-hosted}

# prevent issues with librarian-puppet when run from cloudinit
if test -z "$HOME"; then
  export HOME=/root
fi

if ! test -d code/puppet/vendor/modules; then
  echo "Installing 3rd party Puppet modules (this may take a while)"
  (cd code/puppet; librarian-puppet install) || exit
fi

# ensure secret random seed is present on the host
mkdir -p /var/lib/puppet/
seedfile=/var/lib/puppet/.random_seed
test -f "$seedfile" || \
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64 > "$seedfile"

if test -z "$SHOW_WARNINGS";then
  # errors/warnings to suppress as they often lead to red herrings.
  ignore='Warning:.*collect exported resources.*nginx/manifests/resource/upstream.pp|Info: Loading facts|Warning:.*(Skipping unparsable iptables rule.*br-|is deprecated)|file & line not available|/vendor/modules/.*(deprecation|collect_exported)|validate_legacy.*/vendor'
  echo "Starting server provisioning (ignoring Puppet catalog compiler warnings (deprecations, etc))"
  ignore_filter="egrep --line-buffered -v '$ignore'"
else
  echo "Starting server provisioning (showing Puppet catalog compiler warnings (deprecations, etc))"
  # shellcheck disable=SC2209
  ignore_filter=cat
fi

/opt/puppetlabs/bin/puppet apply \
  --detailed-exitcodes \
  --modulepath=code/puppet/modules:code/puppet/vendor/modules \
  --hiera_config=code/puppet/hiera.yaml \
  --user=root --group=root \
  --execute "include base" "$@" \
    > >(eval $ignore_filter) \
    2> >(eval $ignore_filter)
# detailed exit code 0 and 2 are considered success.
# https://docs.puppet.com/puppet/4.4/reference/man/apply.html#OPTIONS
e=$?; test $e -eq 2 && exit 0
# all others failure
exit $e
