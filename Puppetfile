#!/usr/bin/env ruby
#^syntax detection

forge "https://forgeapi.puppetlabs.com"

mod 'saz-ssh'
# pin to latest puppet 3.x supported version
mod 'puppet-unattended_upgrades', '<=2.2.0'
mod 'puppetlabs-firewall'
# pin to latest puppet 3.x supported version
mod 'puppetlabs-ntp', '<4.2.0'
mod 'petems/swap_file'
mod 'puppetlabs-stdlib'
mod 'puppetlabs-vcsrepo'
mod 'thias-php'
# pin to latest puppet 3.x supported version
mod 'puppetlabs-mysql', '<4.0.0'
mod 'example42-network'
mod 'garethr-docker'
mod 'KyleAnderson/consul', '>=3.0.0'
mod 'puppet/collectd'
mod 'datacentred/telegraf'

mod 'aequitas/letsencrypt',
  :git => 'https://github.com/aequitas/puppet-letsencrypt.git',
  :ref => 'master'
mod 'aequitas/sites',
  :git => 'https://github.com/aequitas/puppet-sites.git',
  :ref => '115c4744a03cf33c9fc9ebaa6c0df0634b865c78'
  # :path => '../../puppet-sites'

# indirect dependencies to pin version
# pin to latest puppet 3.x supported version
mod 'puppet-nginx', '0.6.0'
mod 'puppetlabs-apt', '< 3.0.0'
