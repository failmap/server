# include base configuration applying only to hosted environment and which don't fit easily in hiera
# generic system configuration (users, accounts, ntp, ssh, security, etc)
class base::env::hosted (
  $docker=false,
){

  # enable apt unattended security upgrades
  class { '::apt': }
  class { '::unattended_upgrades': }

  # setup firewall
  class { '::firewall': }
  if $docker {
    # remove all unmanaged firewall rules except for docker engine rules.
    firewallchain { 'FORWARD:filter:IPv4':
      purge  => true,
      ignore => [ 'docker', 'DOCKER-ISOLATION' ],
    }
    firewallchain { 'DOCKER:filter:IPv4':
      purge  => false,
    }
    firewallchain { 'DOCKER-ISOLATION:filter:IPv4':
      purge  => false,
    }
    firewallchain { 'DOCKER:nat:IPv4':
      purge  => false,
    }
    firewallchain { 'POSTROUTING:nat:IPv4':
      purge  => true,
      ignore => [ 'docker', '172.17' ],
    }
    firewallchain { 'PREROUTING:nat:IPv4':
      purge  => true,
      ignore => [ 'DOCKER' ],
    }

    #ensure input rules are cleaned out
    firewallchain { 'INPUT:filter:IPv4':
      ensure => present,
      purge  => true,
    }
  } else {
    # remove all unmanaged firewall rules
    resources { 'firewall':
      purge => true,
    }
  }

  create_resources('firewall', hiera_hash('firewall', {}))

  # enable ntp
  class { '::ntp':
      servers => [
          '0.pool.ntp.org', '1.pool.ntp.org',
          '2.pool.ntp.org', '3.pool.ntp.org'
      ],
  }

  # enable ssh server
  class { '::ssh':
    storeconfigs_enabled => false,
    server_options       => {
      'PasswordAuthentication' => no,
    }
  }

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
