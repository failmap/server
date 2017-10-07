# application independent generic docker daemon configuration
class base::docker {
  # make docker container names resolvable on host OS
  docker::run {'resolver':
    image   => 'mgood/resolvable',
    volumes => [
      '/var/run/docker.sock:/tmp/docker.sock',
      '/etc/resolv.conf:/tmp/resolv.conf',
    ],
  }
}
