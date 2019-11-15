# include base configuration applying only to hosted environment and which don't fit easily in hiera
# generic system configuration (users, accounts, ntp, ssh, security, etc)
class base::env::hosted (
  $docker=false,
){

  # enable apt unattended security upgrades
  class { '::unattended_upgrades': }

  class { 'base::firewall':
    docker => $docker,
  }

  # enable ntp
  class { '::ntp':
      servers => [
          '0.pool.ntp.org', '1.pool.ntp.org',
          '2.pool.ntp.org', '3.pool.ntp.org'
      ],
  }

  # pam sudo ssh agent auth and user accounts
  class { 'accounts': }

  # disable password login if at least one user with ssh key is configured
  $ssh_key_accounts = $::accounts::users.filter | $name, $account | {
    ! empty($account[keys])
  }
  if empty($ssh_key_accounts) {
    $password_authentication = yes
  } else {
    $password_authentication = no
  }

  # enable ssh server
  class { '::ssh':
    storeconfigs_enabled => false,
    server_options       => {
      # improve ssh server security
      'PasswordAuthentication' => $password_authentication,
      'PermitRootLogin'        => no,
    }
  }

  # remind superusers of configurationmanagement
  file {
      '/etc/sudoers.lecture':
            content => "THIS HOST IS MANAGED BY PUPPET. Please only make permanent changes\nthrough puppet and do not expect manual changes to be maintained!\nMore info: https://gitlab.com/internet-cleanup-foundation/server\n\n";
  }
  -> sudo::conf { 'lecture':
    priority => 10,
    content  => "Defaults\tlecture=\"always\"\nDefaults\tlecture_file=\"/etc/sudoers.lecture\"\n",
  }

  swap_file::files { 'default':
      ensure   => present,
  }
}
