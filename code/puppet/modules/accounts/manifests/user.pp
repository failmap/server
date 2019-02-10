# create user accounts, adds ssh keys and optional sudo-pam-ssh key
define accounts::user (
  $ensure=present,
  $sudo=false,
  $keys={},
  $shell='/bin/bash',
  $sudo_key_auth=$accounts::sudo_key_auth,
  Optional[String] $sshpubkey=undef,
  Optional[String] $webpassword=undef
){
  if $sudo {
      $sudo_ensure = present
      $groups = ['sudo', 'docker']
      Package[docker] -> User[$name]
  } else {
      $sudo_ensure = absent
      $groups = []
  }

  case $shell {
    '/usr/bin/fish':{
      ensure_packages(['fish'], {ensure => latest})
      Package[fish] -> User[$name]
    }
    default: {}
  }

  user { $name:
      ensure     => $ensure,
      managehome => true,
      groups     => $groups,
      shell      => $shell,
  }

  if $ensure == present {
    $key_defaults = {
      user     => $name,
    }
    create_resources(ssh_authorized_key, $keys, $key_defaults)

    if $sshpubkey {
      ssh_authorized_key {'default':
        user => $name,
        type => 'ssh-rsa',
        key  => $sshpubkey,
      }
    }
  }

  if $sudo and $sudo_key_auth {
    File[$pam_ssh_agent_auth::key_dir] -> Ssh_authorized_key <||>

    $sudo_key_defaults = {
      ensure => $sudo_ensure,
      user   => 'root',
      target => "/etc/sudo_ssh_authorized_keys/${name}",
    }
    create_resources(ssh_authorized_key, prefix($keys, 'sudo-'), $sudo_key_defaults)
  } else {
    file {"/etc/sudo_ssh_authorized_keys/${name}":
      ensure => absent,
    }
  }
  if $webpassword != '' and $webpassword != undef {
    $passwd = ht_crypt($webpassword, simplib::passgen('htpasswd_seed'))
    concat::fragment { "admin user ${name}":
      target  => '/etc/nginx/admin.htpasswd',
      content => "${name}:${passwd}\n",
    }
  }
}
