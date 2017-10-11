# Configure the failmap worker
class apps::failmap::worker (
  $hostname = 'faalkaart.nl'
){
  include common

  $appname = 'failmap-worker'

  $broker = 'amqp://guest:guest@broker:5672//'

  Docker::Image['registry.gitlab.com/failmap/admin'] ~>
  docker::run { $appname:
    image   => 'registry.gitlab.com/failmap/admin:latest',
    command => 'celery worker',
    env     => [
      "SERVICE_NAME=${appname}",
      "CELERY_BROKER_URL=${broker}",
    ],
    net     => 'broker',
  }
}
