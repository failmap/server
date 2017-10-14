# resources shared by frontend, admin and workers
class apps::failmap (
  $pod='failmap',
){
  docker::image { 'registry.gitlab.com/failmap/admin':
    ensure    => latest,
    image_tag => latest,
  }

  # create application group network before starting containers
  docker_network { $pod:
    ensure => present,
  } -> Docker::Run <| |>
}
