# Configure the Admin frontend as well as the basic service requirements (database, queue broker)
class apps::failmap::admin (
  $hostname  = "admin.${apps::failmap::hostname}",
  $pod       = $apps::failmap::pod,
  $image     = $apps::failmap::image,
  $client_ca = undef,
  $broker    = $apps::failmap::broker,
){
  include ::apps::failmap
  include ::apps::failmap::frontend

  $appname = "${pod}-admin"

  $db_name = 'failmap'
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

  # common options for all docker invocations (ie: cli helpers/service)
  $docker_environment = [
    # database settings
    'APPLICATION_MODE=admin',
    'DJANGO_DATABASE=production',
    'DB_HOST=/var/run/mysqld/mysqld.sock',
    "DB_NAME=${db_name}",
    "DB_USER=${db_user}",
    "DB_PASSWORD=${db_password}",
    # django generic settings
    "SECRET_KEY=${secret_key}",
    "ALLOWED_HOSTS=${hostname}",
    'DEBUG=',
    # message broker settings
    "BROKER=${broker}",
    'STATSD_HOST=172.20.0.1',
  ]

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode   => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
  } -> Docker::Run[$appname]

  Docker::Image[$image]
  ~> docker::run { $appname:
    image           => $image,
    command         => 'runuwsgi',
    volumes         => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap/images/screenshots/:/srv/failmap/static/images/screenshots/',
    ],
    # combine specific and generic docker environment options
    env             => concat($docker_environment,[
      # name by which service is known to service discovery (consul)
      "SERVICE_NAME=${appname}",
      # standard consul HTTP check won't do because of Django ALLOWED_HOSTS
      'SERVICE_CHECK_TCP=true',
    ]),
    env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net             => $pod,
    username        => 'nobody:nogroup',
    tty             => true,
    systemd_restart => 'always',
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.service.dc1.consul:8000",
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    client_ca        => $client_ca,
    # admin is accessible for authenticated users only that need to see a live view
    # of changes, do not cache anything
    caching          => disabled,
    proxy_timeout    => '90s',
  }

  # add convenience command to run admin actions via container
  $docker_environment_args = join(prefix($docker_environment, '-e'), ' ')
  file { '/usr/local/bin/failmap':
    content => "#!/bin/bash\n/usr/bin/docker run --network ${pod} -i ${docker_environment_args} \
                -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
                --name ${pod}-\$(logname)-\$1-\$(date +%s) \
                -e TERM=\$TERM --rm --user nobody ${image} \"\$@\"",
    # this file contains secrets, don't expose to non-root
    mode    => '0700',
  }
  file { '/usr/local/bin/failmap-background':
    content => "#!/bin/bash\n/usr/bin/docker run -d --network ${pod} -i ${docker_environment_args} \
                -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
                --name ${pod}-\$(logname)-\$1-\$(date +%s) \
                -e TERM=\$TERM --rm --user nobody ${image} \"\$@\"",
    # this file contains secrets, don't expose to non-root
    mode    => '0700',
  }
  file { '/usr/local/bin/failmap-shell':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti -e TERM=\$TERM ${appname} /bin/sh",
    mode    => '0744',
  }

  file { '/usr/local/bin/failmap-deploy':
    content => template('apps/failmap-deploy.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/failmap-rollback':
    content => template('apps/failmap-rollback.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/failmap-frontend-cache-flush':
    content => "systemctl stop nginx; rm -r /var/cache/nginx/${::apps::failmap::frontend::hostname}/;systemctl start nginx",
    mode    => '0744',
  }
  file { '/usr/local/bin/failmap-task-queue-flush-all':
    content => '/usr/bin/docker exec broker redis-cli flushall',
    mode    => '0744',
  }
  file { '/usr/local/bin/failmap-logtail':
    content => '/bin/journalctl -f -u docker-failmap-*',
    mode    => '0744',
  }
  file { '/usr/local/bin/failmap-db-migrate':
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
  [Docker::Image[$image], Mysql_database[failmap]]
  ~> exec {"${appname}-migrate":
    command     => '/usr/local/bin/failmap-db-migrate',
    refreshonly => true,
  }
  # Run migration before starting app containers, so apps don't plunge in a
  # unprepared database, this makes sure 'kitchen test' completes in one go
  -> Docker::Run <| |>
  # make sure we only start migrating once mysql server is running
  Service[$::mysql::server::service_name] ~> Exec["${appname}-migrate"]

  # create a compressed rotating dataset backup every day/week
  cron { "${appname} daily dataset backup":
    command => '/usr/local/bin/failmap create-dataset -o - | gzip > /var/backups/failmap_dataset_day_$(date +%u).json.gz',
    hour    => 6,
  }

  cron { "${appname} weekly dataset backup":
    command => '/usr/local/bin/failmap create-dataset -o - | gzip > /var/backups/failmap_dataset_week_$(date +%U).json.gz',
    hour    => 5,
    weekday => 1
  }

  Docker::Image[$image]
  ~> docker::run { 'failmap-flower':
    image           => $image,
    command         => 'celery flower --broker=redis://broker:6379/0 --port=8000',
    # combine specific and generic docker environment options
    env             => [
      # name by which service is known to service discovery (consul)
      'SERVICE_NAME=failmap-flower',
      'SERVICE_CHECK_HTTP=/',
    ],
    net             => $pod,
    username        => 'nobody:nogroup',
    tty             => true,
    systemd_restart => 'always',
  }
  -> sites::vhosts::proxy { "flower.${apps::failmap::hostname}":
    proxy            => 'failmap-flower.service.dc1.consul:8000',
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    client_ca        => $client_ca,
    # admin is accessible for authenticated users only that need to see a live view
    # of changes, do not cache anything
    caching          => disabled,
    proxy_timeout    => '90s',
  }
}
