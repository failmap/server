# Configure the failmap frontend
class apps::failmap::frontend (
  $hostname = 'faalkaart.nl',
  $pod = $apps::failmap::pod,
  $image = $apps::failmap::image,
){
  $appname = "${pod}-frontend"

  $db_name = 'failmap'
  $db_user = "${db_name}ro"

  # database readonly user
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")
  mysql_user { "${db_user}@localhost":
    password_hash => mysql_password($db_password),
  } ->
  mysql_grant { "${db_user}@localhost/${db_name}.*":
    user       => "${db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT'],
  }

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
  } -> Docker::Run[$appname]

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")
  Docker::Image[$image] ~>
  docker::run { $appname:
    image    => $image,
    command  => 'runuwsgi',
    volumes  => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap/images/screenshots/:/srv/failmap/static/images/screenshots/',
    ],
    env      => [
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
      # name by which service is known to service discovery (consul)
      "SERVICE_NAME=${appname}",
    ],
    env_file => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net      => $pod,
    tty      => true,
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy    => "${appname}.service.dc1.consul:8000",
    # use consul as proxy resolver
    resolver => ['127.0.0.1:8600'],
    # allow upstream to set caching headers, cache upstream responses
    # and serve stale results if backend is unavailable or broken
    caching  => upstream,
  }

  file { '/usr/local/bin/failmap-frontend-clear-cache':
    content => template('apps/failmap-frontend-clear-cache.erb'),
    mode    => '0744',
  }
}
