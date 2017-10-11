# configure message broker (rmq)
class apps::failmap::broker (
  $pod = $apps::failmap::pod
){
  docker::run {'broker':
    image => 'rabbitmq',
    net   => $pod
  }
}
