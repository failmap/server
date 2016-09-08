# provide application independent OS layer base settings
class base {
  # generic system configuration (users, accounts, ntp, ssh, security, etc)

  include cron

  # add some resource creations for modules not supporting them natively
  create_resources('host', hiera_hash('hosts', {}))

  # some generic config for every host

  # enable apt unattended security upgrades
  class { '::apt': }
  class { '::unattended_upgrades': }

  # setup firewall
  class { '::firewall': }
  create_resources('firewall', hiera_hash('firewall', {}))

  # utility packages
  package { ['sl', 'atop', 'htop']:
    ensure => latest,
  }

  # enable ntp
  class { '::ntp':
      servers => [
          '0.pool.ntp.org', '1.pool.ntp.org',
          '2.pool.ntp.org', '3.pool.ntp.org'
      ],
  }

  # enable ssh server
  class { '::ssh': }

  # let sudoers know not to change anything outside of puppet
  file {
      '/etc/sudoers.lecture':
            content => "THIS HOST IS MANAGED BY PUPPET. Please only make permanent changes\nthrough puppet and do not expect manual changes to be maintained!\nMore info: https://github.com/failmap/server\n\n";

      '/etc/sudoers.d/lecture':
            content => "Defaults\tlecture=\"always\"\nDefaults\tlecture_file=\"/etc/sudoers.lecture\"\n";
  }

  swap_file::files { 'default':
      ensure   => present,
  }

  # pam sudo ssh agent auth and user accounts
  class { 'pam_ssh_agent_auth': }
  class { 'accounts': }
}
