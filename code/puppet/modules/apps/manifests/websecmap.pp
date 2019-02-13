# resources shared by frontend, admin and workers
class apps::websecmap (
  $hostname='default',
  $pod='websecmap',
  $ipv6_subnet=undef,
  $image='websecmap/websecmap:latest',
  $broker='redis://broker:6379/0',
){
  docker::image { $image:
    ensure    => present,
    image     => 'websecmap/websecmap',
    image_tag => latest,
  }

  if $ipv6_subnet {
    $network_opts = "--ipv6 --subnet=${ipv6_subnet}"
  } else { $network_opts = ''}

  # create application group network before starting containers
  Service['docker']
  -> exec { "${pod} docker network":
    command => "/usr/bin/docker network create ${network_opts} ${pod}",
    unless  => "/usr/bin/docker network inspect ${pod}",
  } -> Docker::Run <| |>

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${pod}":
      ensure => directory,
      mode   => '0700';
    "/srv/${pod}/env.file":
      ensure => present;
  } -> Docker::Run <| |>

  # temporary solution for storing screenshots for live release
  file {
    '/srv/websecmap/images/':
      ensure => directory;
    '/srv/websecmap/images/screenshots/':
      ensure => directory;
  }
}
