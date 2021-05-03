# Configure the Admin frontend as well as the basic service requirements (database, queue broker)
class apps::websecmap::admin (
  $hostname  = "admin.${apps::websecmap::hostname}",
  $pod       = $apps::websecmap::pod,
  $image     = $apps::websecmap::image,
  $client_ca = undef,
  $broker    = $apps::websecmap::broker,
){
  include ::apps::websecmap
  include ::apps::websecmap::frontend

  $appname = "${pod}-admin"

  $db_name = $apps::websecmap::db_name
  $db_user = $db_name

  # database
  $db_password = simplib::passgen($db_user, {'length' => 32})
  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => 'localhost',
    # make default charset and collate explicit
    charset  => utf8,
    collate  => utf8_general_ci,
    # admin requires all permissions to manage database (and migrations)
    grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE', 'CREATE', 'INDEX', 'DROP', 'ALTER', 'REFERENCES'],
  }

  @telegraf::input { "mysql-${db_name}":
    plugin_type => mysql,
    options     => [
      {
        servers => ["${db_user}:${db_password}@unix(/var/run/mysqld/mysqld.sock)/${db_name}"],
      },
    ],
  }

  $secret_key = simplib::passgen('secret_key', {'length' => 32})

  if $hostname == 'admin.default' {
    $allowed_hosts = '*'
  } else {
    $allowed_hosts = join([$hostname, $apps::websecmap::hostname], ',')
  }

  # disable basic auth (user/password authentication) if client certificate authentication is enabled
  if $client_ca {
    $auth_basic = undef
    $auth_basic_user_file = undef
    $location_cfg_append = undef
    $use_remote_user = ''
  } else {
    $auth_basic = 'Admin login'
    $auth_basic_user_file = '/etc/nginx/admin.htpasswd'
    $location_cfg_append = {'proxy_set_header' => "REMOTE_USER \$remote_user"}
    $use_remote_user = 'yes'
  }

  # common options for all docker invocations (ie: cli helpers/service)
  $docker_environment = [
    # database settings
    'APPLICATION_MODE=admin',
    'DJANGO_LOG_LEVEL=INFO',
    'DJANGO_DATABASE=production',
    'DB_HOST=/var/run/mysqld/mysqld.sock',
    "DB_NAME=${db_name}",
    "DB_USER=${db_user}",
    "DB_PASSWORD=${db_password}",
    # django generic settings
    "SECRET_KEY=${secret_key}",
    "ALLOWED_HOSTS=${allowed_hosts}",
    "USE_REMOTE_USER=${use_remote_user}",
    'DEBUG=',
    # message broker settings
    "BROKER=${broker}",
    "STATSD_HOST=${apps::websecmap::hosts['statsd'][ip]}",
    # Fix Celery issue under Python 3.8, See: https://github.com/celery/celery/issues/5761
    'COLUMNS=80',
    # mitigate issue with where on production the value of 'cheaper' is above the value of 'workers'
    # TODO: needs more investigation
    # https://uwsgi-docs.readthedocs.io/en/latest/Cheaper.html
    'UWSGI_CHEAPER=0',
    # reduce the number of default frontend uwsgi workers for memory reasons
    # TODO: needs more tweakers for performance
    'UWSGI_WORKERS=2',
  ]

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode   => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
    '/srv/websecmap-frontend/uploads':
      ensure => directory,
      owner  => nobody,
      group  => nogroup;
  } -> Docker::Run[$appname]

  docker::run { $appname:
    image            => $image,
    command          => 'runuwsgi',
    volumes          => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      '/srv/websecmap-frontend/uploads:/source/websecmap/uploads',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/websecmap/images/screenshots/:/srv/websecmap/static/images/screenshots/',
    ],
    # combine specific and generic docker environment options
    env              => concat($docker_environment,[]),
    env_file         => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net              => $pod,
    username         => 'nobody:nogroup',
    tty              => true,
    systemd_restart  => 'always',
    extra_parameters => "--ip=${apps::websecmap::hosts[$appname][ip]}",
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/internet-cleanup-foundation/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy                => "${apps::websecmap::hosts[$appname][ip]}:8000",
    nowww_compliance     => class_c,
    client_ca            => $client_ca,
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
    location_cfg_append  => $location_cfg_append,
    # admin is accessible for authenticated users only that need to see a live view
    # of changes, do not cache anything
    caching              => disabled,
    proxy_timeout        => '90s',
  }

  # add convenience command to run admin actions via container
  $docker_environment_args = join(prefix($docker_environment, '-e'), ' ')
  file { '/usr/local/bin/websecmap':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti -e TERM=\$TERM ${appname} /usr/local/bin/websecmap \"\$@\"",
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-no-tty':
    content => "#!/bin/bash\n/usr/bin/docker exec -i -e TERM=\$TERM ${appname} /usr/local/bin/websecmap \"\$@\"",
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-background':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti -d -e TERM=\$TERM ${appname} /usr/local/bin/websecmap \"\$@\"",
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-shell':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti -e TERM=\$TERM ${appname} /bin/sh",
    mode    => '0744',
  }

  $admin_ip = $apps::websecmap::hosts["websecmap-admin"][ip]
  file { '/usr/local/bin/websecmap-deploy':
    content => template('apps/websecmap-deploy.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-rollback':
    content => template('apps/websecmap-rollback.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-frontend-cache-flush':
    content => "systemctl stop nginx; rm -r /var/cache/nginx/${::apps::websecmap::frontend::hostname}/;systemctl start nginx",
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-task-queue-flush-all':
    content => '/usr/bin/docker exec broker redis-cli flushall',
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-logtail':
    content => '/bin/journalctl -f -u docker-websecmap-*',
    mode    => '0744',
  }
  file { '/usr/local/bin/websecmap-db-migrate':
    content => @("EOL"),
      #!/bin/bash
      set -e
      /usr/bin/docker run ${docker_environment_args} \
        -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
        ${image} migrate --noinput
      | EOL
    mode    => '0744',
  }

  # run migration in a separate container
  Mysql::Db[$db_name]
  ~> exec {"${appname}-migrate":
    command     => '/usr/local/bin/websecmap-db-migrate',
    refreshonly => true,
  }
  # Run migration before starting app containers, so apps don't plunge in a
  # unprepared database, this makes sure 'kitchen test' completes in one go
  -> Docker::Run <| |>
  # make sure we only start migrating once mysql server is running
  Service[$::mysql::server::service_name] ~> Exec["${appname}-migrate"]

  # create a compressed rotating dataset backup every day/week
  cron { "${appname} daily dataset backup":
    command => '/usr/local/bin/websecmap create-dataset -o - | gzip > /var/backups/websecmap_dataset_day_$(date +%u).json.gz',
    minute  => 0,
    hour    => 6,
  }

  cron { "${appname} weekly dataset backup":
    command => '/usr/local/bin/websecmap create-dataset -o - | gzip > /var/backups/websecmap_dataset_week_$(date +%U).json.gz',
    minute  => 0,
    hour    => 5,
    weekday => 1,
  }

  docker::run { 'websecmap-flower':
    # Disable flower due to memory leak. It eats up 1.5 gigabytes and on doing virtually nothing.
    # This might be re-enabled at a later time.
    ensure          => absent,
    running         => false,
    image           => $image,
    command         => 'celery flower --broker=redis://broker:6379/0 --port=8000',
    # combine specific and generic docker environment options
    env             => concat($docker_environment,[
      # name by which service is known to service discovery (consul)
      'SERVICE_NAME=websecmap-flower',
      'SERVICE_CHECK_HTTP=/',
    ]),
    volumes         => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    net             => $pod,
    username        => 'nobody:nogroup',
    tty             => true,
    systemd_restart => 'always',
  }
  -> sites::vhosts::proxy { "flower.${apps::websecmap::hostname}":
    proxy            => 'websecmap-flower.service.dc1.consul:8000',
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    client_ca        => $client_ca,
    # admin is accessible for authenticated users only that need to see a live view
    # of changes, do not cache anything
    caching          => disabled,
    proxy_timeout    => '90s',
  }

  # file to store users allowed to authenticate to the admin backend
  concat { '/etc/nginx/admin.htpasswd':
    ensure => present,
    owner  => 'www-data',
    group  => root,
    mode   => '0600',
  }
  -> Service[nginx]
  # make sure concat empties the file if there are no users defined
  concat::fragment { 'empty':
    target  => '/etc/nginx/admin.htpasswd',
    content => "# managed by puppet\n",
    order   => 0,
  }

  # cleanup
  file { '/usr/local/bin/websecmap-restart-workers':
    ensure => absent,
  }
  cron { 'daily worker restart':
    ensure  => absent,
    command => '/usr/local/bin/websecmap-restart-workers',
    minute  => 0,
    hour    => 21,
  }
}
