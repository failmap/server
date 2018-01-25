#!/usr/bin/env ruby
#^syntax detection

forge "https://forgeapi.puppetlabs.com"

# mod 'saz-ssh', '>3.0.1'
# until release with new concat dependency is released
# https://github.com/saz/puppet-ssh/pull/233
mod 'saz-ssh',
:git => 'https://github.com/saz/puppet-ssh.git',
:ref => 'fb2de7592b5a75930a6eefb283ce070a3051d9d2'

mod 'puppet-unattended_upgrades'
mod 'puppetlabs-firewall'
mod 'puppetlabs-ntp'
mod 'petems/swap_file'
mod 'puppetlabs-stdlib'
mod 'puppetlabs-vcsrepo'
mod 'thias-php'
mod 'puppetlabs-mysql'
mod 'example42-network'
mod 'puppetlabs-docker'
# pin for puppet4+ compat
mod 'KyleAnderson/consul', '>=3.0.0'
mod 'puppet/collectd'
# pin for puppet4+ compat
mod 'datacentred/telegraf', '>=2.0.0',
  # until 2.0.0 is available from puppet forge.
  :git => 'https://github.com/yankcrime/puppet-telegraf.git',
  :ref => '2.0.0'

mod 'aequitas/letsencrypt',
  :git => 'https://github.com/aequitas/puppet-letsencrypt.git',
  :ref => 'db45a8ca205f39ff6e0d63c9b74caabda1f24bb6'
mod 'aequitas/sites',
  :git => 'https://github.com/aequitas/puppet-sites.git',
  :ref => '1cedfd544b1a66cf24ff7bc3f2ec980276774e01'

