# configure message broker (rmq)
class apps::failmap::broker (
  $pod = $apps::failmap::pod
){
  docker::run { 'broker':
    image => redis,
    tag   => latest,
    net   => $pod,
  }

  @telegraf::input { 'broker-redis':
    plugin_type => redis,
    options     => [
      {servers => ['tcp://redis:6379']},
    ],
  }
}
