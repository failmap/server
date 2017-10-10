# application independent generic docker daemon configuration
class base::docker (
  $systemd = true,
){

  if $systemd {
    class {'::docker': }
  } else{
    class {'::docker':
      # don't run docker daemon inside docker, rely on docker socket being available
      service_state    => stopped,
      # prevent calling systemd commands during container creation
      # https://github.com/garethr/garethr-docker/blob/9335039e7b645cd39e24f5f607b5a80759694bd1/manifests/service.pp#L163
      manage_service   => false,
      service_provider => none,
    }

  }

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
