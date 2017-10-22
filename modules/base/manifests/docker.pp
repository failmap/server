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

  # enable memory accounting for `docker stats`
  # http://awhitehatter.me/debian-jessie-wdocker/
  if ::lsbdistcodename == 'jessie' {
    file_line {'docker memory stats':
      line    => 'GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=memory swapaccount=1"',
      match   => 'GRUB_CMDLINE_LINUX_DEFAULT',
      replace => true,
      path    => '/etc/default/grub',
    } ~> exec {'update grub':
      command     => '/usr/sbin/update-grub',
      refreshonly => true,
    }
  }
}
