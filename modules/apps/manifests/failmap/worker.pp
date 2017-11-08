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
    'STATSD_HOST=172.20.0.1',
  ]

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
  } -> Docker::Run[$appname]

  Docker::Image[$image] ~>
  docker::run { $appname:
    image          => $image,
    command        => 'celery worker -linfo',
    volumes        => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env            => $docker_environment,
    env_file       => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net            => $pod,
    # since we use pickle with celery avoid startup error when runing as root
    username       => 'nobody:nogroup',
    tty            => true,
    # give tasks 5 minutes to finish cleanly
    stop_wait_time => 300,
  }

  Docker::Image[$image] ~>
  docker::run { 'failmap-scheduler':
    image    => $image,
    command  => 'celery beat -linfo --pidfile=/var/tmp/celerybeat.pid',
    volumes  => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env      => $docker_environment,
    env_file => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net      => $pod,
    username => 'nobody:nogroup',
    tty      => true,
  }
}
