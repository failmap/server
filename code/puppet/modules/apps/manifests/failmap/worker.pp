# Configure the failmap worker
class apps::failmap::worker (
  $hostname              = $apps::failmap::hostname,
  $pod                   = $apps::failmap::pod,
  $image                 = $apps::failmap::image,
  $broker                = $apps::failmap::broker,
  Hash[String, Array[String]] $workers_configuration = {},
){
  $appname = "${pod}-worker"

  $db_name = 'failmap'
  $db_user = $db_name

  # database

  $db_password = simplib::passgen($db_user, {'length' => 32})

  if $apps::failmap::ipv6_subnet {
    $ipv6_support = 1
  } else {
    $ipv6_support = 0
  }

  $docker_environment = [
    "BROKER=${broker}",
    # worker required db access for non-scanner tasks (eg: rating rebuild)
    'DJANGO_DATABASE=production',
    'DB_HOST=/var/run/mysqld/mysqld.sock',
    "DB_NAME=${db_name}",
    "DB_USER=${db_user}",
    "DB_PASSWORD=${db_password}",
    'STATSD_HOST=172.20.0.1',
    # indicate if this host is capable of running ipv6 tasks.
    "NETWORK_SUPPORTS_IPV6=${ipv6_support}",
  ]

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode   => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
  }

  # three worker instances are created, one for generic administrative tasks (storage),
  # one for 'normal' scanners and one for rate limited qualys scanners
  $worker_roles = ['storage', 'scanner', 'scanner_qualys', 'scanner_endpoint_discovery']
  $worker_roles.each | $role | {
    if $workers_configuration[$role] {
      $worker_args = join($workers_configuration[$role], ' ')
    } else {
      $worker_args = ''
    }

    Docker::Image[$image]
    ~> docker::run { "${appname}-${role}":
      image           => $image,
      # be informative and run memory efficient worker pool
      command         => "celery worker --loglevel=info --pool=eventlet ${worker_args}",
      volumes         => [
        # make mysql accesible from within container
        '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      ],
      env             => $docker_environment + [
        # what tasks this worker should execute
        "WORKER_ROLE=${role}",
        "HOST_HOSTNAME=${::fqdn}",
      ],
      env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
      net             => $pod,
      # since we use pickle with celery avoid startup error when runing as root
      username        => 'nobody:nogroup',
      tty             => true,
      # give tasks 5 minutes to finish cleanly
      stop_wait_time  => 300,
      systemd_restart => 'always',
    }
    File["/srv/${appname}/"] -> Docker::Run["${appname}-${role}"]
  }

  Docker::Image[$image]
  ~> docker::run { 'failmap-scheduler':
    image           => $image,
    command         => 'celery beat -linfo --pidfile=/var/tmp/celerybeat.pid',
    volumes         => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env             => $docker_environment,
    env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net             => $pod,
    username        => 'nobody:nogroup',
    tty             => true,
    systemd_restart => 'always',
  }
}
