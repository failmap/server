# Configure the Admin frontend as well as the basic service requirements (database, queue broker)
class apps::failmap::admin (
  $pod = $apps::failmap::pod,
  $client_ca=undef,
){
  $broker = 'amqp://guest:guest@broker:5672//'

  $hostname = 'admin.faalkaart.nl'
  $appname = 'failmap-admin'

  $db_name = 'failmap'
  $db_user = $db_name

  $image = 'registry.gitlab.com/failmap/admin:latest'

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
    image   => $image,
    command => 'runuwsgi',
    volumes => [
      # make mysql accesible from within container
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
      # message broker settings
      "CELERY_BROKER_URL=${broker}",
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
    webroot          => "/srv/${appname}/",
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    client_ca        => $client_ca,
  }

  # add convenience command to run admin actions via container
  file { '/usr/local/bin/failmap-admin':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti ${appname} $(basename \"\$0\") \$*",
    mode    => '0755',
  }
  file { '/usr/local/bin/failmap-admin-shell':
    content => "#!/bin/bash\n/usr/bin/docker exec -ti ${appname} /bin/bash",
    mode    => '0755',
  }

}
