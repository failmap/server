
# Configure the failmap frontend
class apps::failmap::frontend (
  $hostname = $apps::failmap::hostname,
  $pod = $apps::failmap::pod,
  $image = $apps::failmap::image,
){
  $appname = "${pod}-frontend"

  $db_name = 'failmap'
  $db_user = "${db_name}ro"
  $interactive_db_user = "${db_name}rw"

  # database readonly user
  # used for frontend instance, ie: high traffic public facing.
  # should only be able to read from database
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")
  mysql_user { "${db_user}@localhost":
    password_hash => mysql_password($db_password),
  }
  -> mysql_grant { "${db_user}@localhost/${db_name}.*":
    user       => "${db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT'],
  }

  # database interactive user
  # used for interactive components (eg: login (non-admin), url/org submit)
  # has write access to the database content
  $interactive_random_seed = file('/var/lib/puppet/.random_seed')
  $interactive_db_password = fqdn_rand_string(32, '', "${interactive_random_seed}${interactive_db_user}")
  mysql_user { "${interactive_db_user}@localhost":
    password_hash => mysql_password($interactive_db_password),
  }
  -> mysql_grant { "${interactive_db_user}@localhost/${db_name}.*":
    user       => "${interactive_db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
  }

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${appname}/":
      ensure => directory,
      mode   => '0700';
    "/srv/${appname}/env.file":
      ensure => present;
  } -> Docker::Run[$appname]

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")

  # frontend instance, used for serving readonly content to high traffic public
  Docker::Image[$image]
  ~> docker::run { $appname:
    image           => $image,
    command         => 'runuwsgi',
    volumes         => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap/images/screenshots/:/srv/failmap/static/images/screenshots/',
    ],
    env             => [
      # database settings
      'APPLICATION_MODE=frontend',
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
      # HTTP check won't do because of Django ALLOWED_HOSTS
      "SERVICE_CHECK_SCRIPT=curl\\ -si\\ http://\$SERVICE_IP/\\ -Hhost:${appname}\\|grep\\ 200\\ OK",
    ],
    env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net             => $pod,
    tty             => true,
    systemd_restart => 'always',
  }

  # interactive instance, used for serving interactive parts (not admin) to authenticated/limited audience
  Docker::Image[$image]
  ~> docker::run { "${pod}-interactive":
    image           => $image,
    command         => 'runuwsgi',
    volumes         => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/failmap/images/screenshots/:/srv/failmap/static/images/screenshots/',
    ],
    env             => [
      # database settings
      'APPLICATION_MODE=interactive',
      'DJANGO_DATABASE=production',
      'DB_HOST=/var/run/mysqld/mysqld.sock',
      "DB_NAME=${db_name}",
      "DB_USER=${interactive_db_user}",
      "DB_PASSWORD=${interactive_db_password}",
      # django generic settings
      "SECRET_KEY=${secret_key}",
      "ALLOWED_HOSTS=${hostname}",
      'DEBUG=',
      # name by which service is known to service discovery (consul)
      "SERVICE_NAME=${pod}-interactive",
      # HTTP check won't do because of Django ALLOWED_HOSTS
      "SERVICE_CHECK_SCRIPT=curl\\ -si\\ http://\$SERVICE_IP/\\ -Hhost:${appname}\\|grep\\ 200\\ OK",
    ],
    env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net             => $pod,
    tty             => true,
    systemd_restart => 'always',
  }

  sites::vhosts::proxy { $hostname:
    proxy    => "${appname}.service.dc1.consul:8000",
    # use consul as proxy resolver
    resolver => ['127.0.0.1:8600'],
    # allow upstream to set caching headers, cache upstream responses
    # and serve stale results if backend is unavailable or broken
    caching  => upstream,
  }

  file { "/etc/nginx/conf.d/${hostname}.rate_limit.conf":
    ensure  => present,
    content => "limit_req_zone \$binary_remote_addr zone=authentication:10m rate=3r/s;"
  } ~> Nginx::Resource::Server[$hostname]

  file { "/etc/nginx/conf.d/${hostname}.game.rate_limit.conf":
    ensure  => present,
    content => "limit_req_zone \$binary_remote_addr zone=game:10m rate=10r/s;"
  } ~> Nginx::Resource::Server[$hostname]

  nginx::resource::location { "${hostname}-authentication":
    server                     => $hostname,
    ssl                        => true,
    ssl_only                   => true,
    www_root                   => undef,
    location                   => '/authentication/',
    proxy                      => "\$backend",
    location_custom_cfg_append => {
      'set'       => "\$backend http://${pod}-interactive.service.dc1.consul:8000;",
      'limit_req' => 'zone=authentication;',
    }
  }

  nginx::resource::location { "${hostname}-game":
    server                     => $hostname,
    ssl                        => true,
    ssl_only                   => true,
    www_root                   => undef,
    location                   => '/game/',
    proxy                      => "\$backend",
    location_custom_cfg_append => {
      'set'                => "\$backend http://${pod}-interactive.service.dc1.consul:8000;",
      # if not authenticated this endpoint is not visible
      'if'                 => "(\$cookie_sessionid = \"\") { return 404; }",
      'proxy_no_cache'     => "\$cookie_sessionid;",
      'proxy_cache_bypass' =>  "\$cookie_sessionid;",
    },
  }

  nginx::resource::location { "${hostname}-game-public":
    server                     => $hostname,
    ssl                        => true,
    ssl_only                   => true,
    www_root                   => undef,
    location                   => '/game/scores/',
    proxy                      => "\$backend",
    location_custom_cfg_append => {
      'set'                => "\$backend http://${pod}-frontend.service.dc1.consul:8000;",
      'limit_req'          => 'zone=game;',
      'proxy_no_cache'     =>'yes;',
      'proxy_cache_bypass' =>'yes;',
    },
  }

  file { '/usr/local/bin/failmap-frontend-clear-cache':
    content => template('apps/failmap-frontend-clear-cache.erb'),
    mode    => '0744',
  }
}
