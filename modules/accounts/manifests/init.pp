class accounts (
  $users={},
){
  create_resources(accounts::user, $users, {})
}
