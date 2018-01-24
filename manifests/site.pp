# get env from hiera if not provided by facter (enviroment var FACTER_env)
if $env == undef {
  $env = hiera('env')
}

# debug context
notice("fqdn: ${::fqdn}, env: ${env}")

# no node definitions here, get all config from hiera
# https://docs.puppet.com/hiera/3.1/puppet.html#assigning-classes-to-nodes-with-hiera-hierainclude
lookup('classes', {merge => unique}).include

