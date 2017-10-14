# Configure the failmap worker
class apps::failmap::worker (
  $hostname = 'faalkaart.nl',
  $pod = $apps::failmap::pod,
  $image = $apps::failmap::image,
){
  $appname = 'failmap-worker'

  $broker = 'amqp://guest:guest@broker:5672//'

  Docker::Image[$image] ~>
  docker::run { $appname:
    image   => $image,
    command => 'celery worker',
    env     => [
      "SERVICE_NAME=${appname}",
      "CELERY_BROKER_URL=${broker}",
    ],
    net     => $pod,
  }
}
