# configure firewall
class base::firewall (
  Boolean $docker = false,
  Hash $rules = {},
){
  # setup firewall
  class { '::firewall': }
  if $docker {
    # remove all unmanaged firewall rules except for docker engine rules.
    firewallchain { 'FORWARD:filter:IPv4':
      purge  => true,
      ignore => [ '(?i)(docker|DOCKER-ISOLATION|br-)' ],
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
      ignore => [ 'docker', '172\.' ],
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
  create_resources(firewall, $rules)

  # collect all firewall rules declared in other modules (@firewall {...)
  Firewall <| |>
}
