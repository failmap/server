# create user account from hiera
class accounts (
  $users={},
  $sudo_key_auth=false,
){
  create_resources(accounts::user, $users, {})

  class { 'sudo': }
  if $sudo_key_auth {
    sudo::conf { 'sudo':
      priority => 10,
      content  => "%sudo   ALL=(ALL:ALL) ALL",
    }
  } else {
    sudo::conf { 'sudo':
      priority => 10,
      content  => "%sudo   ALL=(ALL) NOPASSWD: ALL",
    }
  }
}
