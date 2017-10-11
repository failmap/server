# resources shared by frontend, admin and workers
class apps::failmap (
  $pod='failmap',
){
  docker::image { 'registry.gitlab.com/failmap/admin':
    ensure    => latest,
    image_tag => latest,
  }

  docker_network { $pod:
    ensure => present,
  }
}
