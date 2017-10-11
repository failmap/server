# configure message broker (rmq)
class base::broker {
  Docker_network[broker] ->
  docker::run {'broker':
    image => 'rabbitmq',
    net   => 'broker'
  }
}
