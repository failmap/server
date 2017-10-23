# Configure the failmap frontend
class apps::failmap::frontend (
  $hostname = 'faalkaart.nl',
  $pod = $apps::failmap::pod,
  $image = $apps::failmap::image,
){
  $appname = 'failmap-frontend'

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

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")
  Docker::Image[$image] ~>
  docker::run { $appname:
    image   => $image,
    command => 'runuwsgi',
    volumes => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap-admin/images/screenshots/:/srv/failmap-admin/static/images/screenshots/',
    ],
    env     => [
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
    net     => $pod,
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.service.${base::consul::dc}.consul:8000",
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    # allow upstream to set caching headers, cache upstream responses
    # and serve stale results if backend is unavailable or broken
    caching          => upstream,
  }
}
