# resources shared by frontend, admin and workers
class apps::failmap (
  $pod='failmap',
  $image='registry.gitlab.com/failmap/admin:latest',
){
  docker::image { $image:
    ensure    => latest,
    image     => 'registry.gitlab.com/failmap/admin',
    image_tag => latest,
  }

  # create application group network before starting containers
  docker_network { $pod:
    ensure => present,
  } -> Docker::Run <| |>

  # temporary solution for storing screenshots for live release
  file {
    '/srv/failmap-admin/':
      ensure => directory;
    '/srv/failmap-admin/images/':
      ensure => directory;
    '/srv/failmap-admin/images/screenshots/':
      ensure => directory;
  }
}
