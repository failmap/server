# configure message broker (rmq)
class base::broker {
  docker::run {'broker':
    image   => 'rabbitmq',
  }
}
