# Configure the Admin frontend as well as the basic service requirements (database, queue broker)
class apps::failmap::admin (
  $pod       = $apps::failmap::pod,
  $image     = $apps::failmap::image,
  $client_ca = undef,
  $broker    = $apps::failmap::broker,
){
  $hostname = 'admin.faalkaart.nl'
  $appname = "${pod}-admin"

  $db_name = 'failmap'
  $db_user = $db_name

  # database
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")
  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => 'localhost',
    # make default charset and collate explicit
    charset  => utf8,
    collate  => utf8_general_ci,
    # admin requires all permissions to manage database (and migrations)
    grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE', 'CREATE', 'INDEX', 'DROP', 'ALTER'],
  }

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")
  $docker_environment = [
    # database settings
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
    # name by which service is known to service discovery (consul)
    "SERVICE_NAME=${appname}",
    'SERVICE_8000_CHECK_TCP=/',
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
    image    => $image,
    command  => 'runuwsgi',
    volumes  => [
      # make mysql accesible from within container
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap/images/screenshots/:/srv/failmap/static/images/screenshots/',
    ],
    env      => $docker_environment,
    env_file => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net      => $pod,
    username => 'nobody:nogroup',
    tty      => true,
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
  }

  # add convenience command to run admin actions via container
  $docker_environment_args = join(prefix($docker_environment, '-e'), ' ')
  file { '/usr/local/bin/failmap':
    content => "#!/bin/bash\n/usr/bin/docker run --network ${pod} -i ${docker_environment_args} \
                -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
                -e TERM=\$TERM --rm --user nobody ${image} \"\$@\"",
    # this file contains secrets, don't expose to non-root
    mode    => '0700',
  }
  file { '/usr/local/bin/failmap-background':
    content => "#!/bin/bash\n/usr/bin/docker run -d --network ${pod} -i ${docker_environment_args} \
                -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
                -e TERM=\$TERM --rm --user nobody ${image} \"\$@\"",
    # this file contains secrets, don't expose to non-root
    mode    => '0700',
  }
  file { '/usr/local/bin/failmap-shell':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti -e TERM=\$TERM ${appname} /bin/bash",
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


  # run migration in a separate container
  Docker::Image[$image] ~>
  exec {"${appname}-migrate":
    command     => "/usr/bin/docker run ${docker_environment_args} \
                    -v /var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock \
                    ${image} migrate --noinput",
    refreshonly => true,
  }

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
}
