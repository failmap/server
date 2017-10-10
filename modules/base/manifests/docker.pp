# application independent generic docker daemon configuration
class base::docker {
  # use consul to provide service discovery and host->container DNS
  include consul

  # register docker container with consul for service discovery
  docker::run {'register':
    image   => 'gliderlabs/registrator:latest',
    net     => host,
    volumes => [
      '/var/run/docker.sock:/tmp/docker.sock',
    ],
    command => '-internal consul://localhost:8500',
  }
}
