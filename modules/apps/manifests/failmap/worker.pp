# Configure the failmap worker
class apps::failmap::worker (
  $hostname = 'faalkaart.nl',
  $pod      = $apps::failmap::pod,
  $image    = $apps::failmap::image,
  $broker   = $apps::failmap::broker,
){
  $appname = 'failmap-worker'

  $db_name = 'failmap'
  $db_user = $db_name

  # database
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")

  $docker_environment = [
    "SERVICE_NAME=${appname}",
    "BROKER=${broker}",
    # worker required db access for non-scanner tasks (eg: rating rebuild)
    'DJANGO_DATABASE=production',
    'DB_HOST=/var/run/mysqld/mysqld.sock',
    "DB_NAME=${db_name}",
    "DB_USER=${db_user}",
    "DB_PASSWORD=${db_password}",
  ]

  Docker::Image[$image] ~>
  docker::run { $appname:
    image    => $image,
    command  => 'celery worker -linfo',
    volumes  => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env      => $docker_environment,
    net      => $pod,
    # since we use pickle with celery avoid startup error when runing as root
    username => 'nobody:nogroup',
  }

  Docker::Image[$image] ~>
  docker::run { 'failmap-scheduler':
    image    => $image,
    command  => 'celery beat -linfo',
    volumes  => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env      => $docker_environment,
    net      => $pod,
    username => 'nobody:nogroup',
  }
}
