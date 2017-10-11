# Configure the failmap frontend
class apps::failmap::frontend (
  $hostname = 'faalkaart.nl',
  $pod = $apps::failmap::pod,
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

  Class['docker'] ->
  file { "/srv/${appname}/":
    ensure => directory,
  } ->
  exec { "docker-volume-${appname}-static":
    command => "/usr/bin/docker volume create --name ${appname}-static --opt type=none --opt device=/srv/${appname}/ --opt o=bind",
    unless  => "/usr/bin/docker volume inspect ${appname}-static",
  } -> Docker::Run[$appname]

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")
  Docker::Image['registry.gitlab.com/failmap/admin'] ~>
  docker::run { $appname:
    image   => 'registry.gitlab.com/failmap/admin:latest',
    command => 'runuwsgi',
    volumes => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # expose static files to host for direct serving by webserver
      # /srv/failmap-admin is a hardcoded path in admin app settings
      "${appname}-static:/srv/failmap-admin/",
    ],
    env     => [
      # database settings
      'DB_ENGINE=mysql',
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
    net => $pod,
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.service.${base::consul::dc}.consul:8000",
    webroot          => "/srv/${appname}/",
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
  }
}
