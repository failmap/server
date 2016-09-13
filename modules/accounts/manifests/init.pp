# create user account from hiera
class accounts (
  $users={},
){
  create_resources(accounts::user, $users, {})
}
