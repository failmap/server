# resources shared by frontend, admin and workers
class apps::failmap (
  $pod='failmap',
  $image='registry.gitlab.com/failmap/admin:latest',
  $broker='redis://broker.failmap:6379/0',
){
  docker::image { $image:
    ensure    => present,
    image     => 'registry.gitlab.com/failmap/admin',
    image_tag => latest,
  }

  # create application group network before starting containers
  docker_network { $pod:
    ensure => present,
  } -> Docker::Run <| |>

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${pod}":
      ensure => directory,
      mode => '0700';
    "/srv/${pod}/env.file":
      ensure => present;
  } -> Docker::Run <| |>

  # temporary solution for storing screenshots for live release
  file {
    '/srv/failmap-admin/images/':
      ensure => directory;
    '/srv/failmap-admin/images/screenshots/':
      ensure => directory;
  }
}
