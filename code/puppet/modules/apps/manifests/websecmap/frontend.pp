
# Configure the websecmap frontend
class apps::websecmap::frontend (
  $hostname = $apps::websecmap::hostname,
  $pod = $apps::websecmap::pod,
  $image = $apps::websecmap::image,
  # by default assume www. is not configured
  $default_nowww_compliance = class_c,
){
  $appname = "${pod}-frontend"

  $db_name = $apps::websecmap::db_name
  $db_user = "${db_name}ro"
  $interactive_db_user = "${db_name}rw"

  if $hostname == 'default' {
    $nowww_compliance = 'class_c'
    $default_vhost = true
    $allowed_hosts = '*'
  } else {
    $nowww_compliance = $default_nowww_compliance
    $default_vhost = false
    $allowed_hosts = $hostname
  }

  # database readonly user
  # used for frontend instance, ie: high traffic public facing.
  # should only be able to read from database

  $db_password = simplib::passgen($db_user, {'length' => 32})
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
  $interactive_db_password = simplib::passgen($interactive_db_user, {'length' => 32})
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

  $secret_key = simplib::passgen('secret_key', {'length' => 32})

  # frontend instance, used for serving readonly content to high traffic public
  Docker::Image[$image]
  ~> docker::run { $appname:
    image           => $image,
    command         => 'runuwsgi',
    volumes         => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
      '/srv/websecmap-frontend/uploads:/source/websecmap/uploads',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/websecmap/images/screenshots/:/srv/websecmap/static/images/screenshots/',
    ],
    env             => [
      # database settings
      'APPLICATION_MODE=frontend',
      'DJANGO_LOG_LEVEL=INFO',
      'DJANGO_DATABASE=production',
      'DB_HOST=/var/run/mysqld/mysqld.sock',
      "DB_NAME=${db_name}",
      "DB_USER=${db_user}",
      "DB_PASSWORD=${db_password}",
      # django generic settings
      "SECRET_KEY=${secret_key}",
      "ALLOWED_HOSTS=${allowed_hosts}",
      'DEBUG=',
      # name by which service is known to service discovery (consul)
      "SERVICE_NAME=${appname}",
      # standard consul HTTP check won't do because of Django ALLOWED_HOSTS
      'SERVICE_CHECK_TCP=true',
      # Fix Celery issue under Python 3.8, See: https://github.com/celery/celery/issues/5761
      'COLUMNS=80',
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
      '/srv/websecmap-frontend/uploads:/source/websecmap/uploads',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/websecmap/images/screenshots/:/srv/websecmap/static/images/screenshots/',
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
      "ALLOWED_HOSTS=${allowed_hosts}",
      'DEBUG=',
      # name by which service is known to service discovery (consul)
      "SERVICE_NAME=${pod}-interactive",
      # standard consul HTTP check won't do because of Django ALLOWED_HOSTS
      'SERVICE_CHECK_TCP=true',
      # Fix Celery issue under Python 3.8, See: https://github.com/celery/celery/issues/5761
      'COLUMNS=80',
    ],
    env_file        => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net             => $pod,
    tty             => true,
    systemd_restart => 'always',
  }

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.service.dc1.consul:8000",
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    # allow upstream to set caching headers, cache upstream responses
    # and serve stale results if backend is unavailable or broken
    caching          => upstream,
    proxy_timeout    => '60s',
    # default timeout if not provided by upstream, make odd number to easily identify in web inspecter.
    expires          => 599,
    # if no explicit domainname is set fall back to listening on everything
    default_vhost    => $default_vhost,
    nowww_compliance => $nowww_compliance,
  }

  $auth_basic = 'Admin login'
  $auth_basic_user_file = '/etc/nginx/admin.htpasswd'
  $remote_user_header = {'proxy_set_header' => "REMOTE_USER \$remote_user"}

  nginx::resource::location { 'frontend-grafana':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "\$backend",
    location_cfg_append  => merge({
      'set $backend' => 'http://grafana.service.dc1.consul:3000',
    }, $remote_user_header),
    location             => '/grafana/',
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { 'frontend-admin':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "\$backend",
    location_cfg_append  => merge({
      'set $backend' => 'http://websecmap-admin.service.dc1.consul:8000',
    }, $remote_user_header),
    location             => '/admin/',
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/manage/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "\$backend",
    location_cfg_append  => merge({
      'set $backend' => 'http://websecmap-admin.service.dc1.consul:8000/',
    }, $remote_user_header),
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  # the API is available after authentication, and has their own authentication routines.
  # Functionality of the API is only available after authentication.
  nginx::resource::location { '/api/':
    server                     => $apps::websecmap::hostname,
    ssl                        => true,
    ssl_only                   => true,
    www_root                   => undef,
    proxy                      => "\$backend",
    location_custom_cfg_append => {
      'set'                => "\$backend http://${pod}-interactive.service.dc1.consul:8000;",
    },
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

  nginx::resource::location { "${hostname}-maptile-proxy":
    server                     => $hostname,
    ssl                        => true,
    ssl_only                   => true,
    www_root                   => undef,
    location                   => '/proxy/',
    proxy                      => "\$backend",
    expires                    => '7d',
    location_custom_cfg_append => {
      'set'                  => "\$backend http://${pod}-frontend.service.dc1.consul:8000;",
    },
  }

  file { '/usr/local/bin/websecmap-frontend-clear-cache':
    content => template('apps/websecmap-frontend-clear-cache.erb'),
    mode    => '0744',
  }
}
