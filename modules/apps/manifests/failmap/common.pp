# resources shared by frontend, admin and workers
class apps::failmap::common {
  docker::image { 'registry.gitlab.com/failmap/admin':
    ensure    => latest,
    image_tag => latest,
  }
}
