# create user accounts, adds ssh keys and optional sudo-pam-ssh key
define accounts::user (
  $ensure=present,
  $sudo=false,
  $keys={},
  $shell='/bin/bash',
){
  if $sudo {
      $sudo_ensure = present
      $groups = ['sudo']
  } else {
      $sudo_ensure = absent
      $groups = []
  }

  user { $name:
      ensure     => $ensure,
      managehome => true,
      groups     => $groups,
      shell      => $shell,
  }

  $key_defaults = {
    ensure   => $ensure,
    user     => $name,
  }
  create_resources(ssh_authorized_key, $keys, $key_defaults)

  if $sudo {
    File[$pam_ssh_agent_auth::key_dir] -> Ssh_authorized_key <||>

    $sudo_key_defaults = {
      ensure => $sudo_ensure,
      user   => 'root',
      target => "/etc/sudo_ssh_authorized_keys/${name}",
    }
    create_resources(ssh_authorized_key, prefix($keys, 'sudo-'), $sudo_key_defaults)
  }
}
