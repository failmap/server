# Configure the websecmap frontend
class apps::websecmap::frontend (
  $hostname = $apps::websecmap::hostname,
  $pod = $apps::websecmap::pod,
  $image = $apps::websecmap::image,
  # by default assume www. is not configured
  $default_nowww_compliance = class_c,
  $subdomains = [],
  $broker    = $apps::websecmap::broker,
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
    password_hash => mysql::password($db_password),
  }
  -> mysql_grant { "${db_user}@localhost/${db_name}.*":
    user       => "${db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT'],
  }
  mysql_user { "${db_user}@172.17.0.%":
    password_hash => mysql::password($db_password),
  }
  -> mysql_grant { "${db_user}@172.17.0.%/${db_name}.*":
    user       => "${db_user}@172.17.0.%",
    table      => "${db_name}.*",
    privileges => ['SELECT'],
  }

  # database interactive user
  # used for interactive components (eg: login (non-admin), url/org submit)
  # has write access to the database content
  $interactive_db_password = simplib::passgen($interactive_db_user, {'length' => 32})
  mysql_user { "${interactive_db_user}@localhost":
    password_hash => mysql::password($interactive_db_password),
  }
  -> mysql_grant { "${interactive_db_user}@localhost/${db_name}.*":
    user       => "${interactive_db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
  }
  mysql_user { "${interactive_db_user}@172.17.0.%":
    password_hash => mysql::password($interactive_db_password),
  }
  -> mysql_grant { "${interactive_db_user}@172.17.0.%/${db_name}.*":
    user       => "${interactive_db_user}@172.17.0.%",
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
  docker::run { $appname:
    image            => $image,
    command          => 'runuwsgi',
    volumes          => [
      '/srv/websecmap-frontend/uploads:/source/websecmap/uploads',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/websecmap/images/screenshots/:/srv/websecmap/static/images/screenshots/',
    ],
    env              => [
      # database settings
      'APPLICATION_MODE=frontend',
      'DJANGO_LOG_LEVEL=INFO',
      'DJANGO_DATABASE=production',
      'DB_HOST=mysql',
      "DB_NAME=${db_name}",
      "DB_USER=${db_user}",
      "DB_PASSWORD=${db_password}",
      # django generic settings
      "SECRET_KEY=${secret_key}",
      "ALLOWED_HOSTS=${allowed_hosts}",
      'DEBUG=',
      # Fix Celery issue under Python 3.8, See: https://github.com/celery/celery/issues/5761
      'COLUMNS=80',
      # mitigate issue with where on production the value of 'cheaper' is above the value of 'workers'
      # TODO: needs more investigation
      # https://uwsgi-docs.readthedocs.io/en/latest/Cheaper.html
      'UWSGI_CHEAPER=0',
      # reduce the number of default frontend uwsgi workers for memory reasons
      # TODO: needs more tweakers for performance
      'UWSGI_WORKERS=2',
    ],
    env_file         => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net              => $pod,
    tty              => true,
    systemd_restart  => 'always',
    extra_parameters => "--ip=${apps::websecmap::hosts[$appname][ip]}",
    hostentries      => $apps::websecmap::hostentries,
  }

  # interactive instance, used for serving interactive parts (not admin) to authenticated/limited audience
  docker::run { "${pod}-interactive":
    image            => $image,
    command          => 'runuwsgi',
    volumes          => [
      '/srv/websecmap-frontend/uploads:/source/websecmap/uploads',
      # temporary solution to allow screenshots to be hosted for live release
      '/srv/websecmap/images/screenshots/:/srv/websecmap/static/images/screenshots/',
    ],
    env              => [
      # database settings
      'APPLICATION_MODE=interactive',
      'DJANGO_DATABASE=production',
      'DB_HOST=mysql',
      "DB_NAME=${db_name}",
      "DB_USER=${interactive_db_user}",
      "DB_PASSWORD=${interactive_db_password}",
      # django generic settings
      "SECRET_KEY=${secret_key}",
      "ALLOWED_HOSTS=${allowed_hosts}",
      'USE_REMOTE_USER=yes',
      "BROKER=${broker}",
      'DEBUG=',
      # TODO: needs more investigation
      # https://uwsgi-docs.readthedocs.io/en/latest/Cheaper.html
      'UWSGI_CHEAPER=0',
    ],
    env_file         => ["/srv/${appname}/env.file", "/srv/${pod}/env.file"],
    net              => $pod,
    tty              => true,
    systemd_restart  => 'always',
    extra_parameters => "--ip=${apps::websecmap::hosts["${pod}-interactive"][ip]}",
    hostentries      => $apps::websecmap::hostentries,
  }

  sites::vhosts::proxy { $hostname:
    proxy               => "${appname}:8000",
    # allow upstream to set caching headers, cache upstream responses
    # and serve stale results if backend is unavailable or broken
    caching             => upstream,
    proxy_timeout       => '60s',
    # default timeout if not provided by upstream, make odd number to easily identify in web inspecter.
    expires             => 599,
    # if no explicit domainname is set fall back to listening on everything
    default_vhost       => $default_vhost,
    nowww_compliance    => $nowww_compliance,
    subdomains          => $subdomains,
    # prevent cookies from disabling caching on frontpage
    location_cfg_append => {'proxy_ignore_headers' => 'Set-Cookie'},
  }

  $auth_basic = 'Admin login'
  $auth_basic_user_file = '/etc/nginx/admin.htpasswd'
  $remote_user_header = {'proxy_set_header' => "REMOTE_USER \$remote_user"}

  nginx::resource::location { '/admin/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "http://${apps::websecmap::hosts["${pod}-admin"][ip]}:8000",
    location_cfg_append  => merge({}, $remote_user_header),
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/manage/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "http://${apps::websecmap::hosts["${pod}-admin"][ip]}:8000/",
    location_cfg_append  => merge({
      'proxy_no_cache'     =>'yes',
      'proxy_cache_bypass' =>'yes',
    }, $remote_user_header),
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  # the API is available after authentication, and has their own authentication routines.
  # Functionality of the API is only available after authentication.
  nginx::resource::location { '/api/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "http://${apps::websecmap::hosts["${pod}-interactive"][ip]}:8000",
    location_cfg_append  => merge({}, $remote_user_header),
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/metrics/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => 'http://127.0.0.1:9100/metrics',
    location_cfg_append  => {
      'proxy_no_cache'     =>'yes',
      'proxy_cache_bypass' =>'yes',
    },
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/statsd/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => 'http://statsd:9102/metrics',
    location_cfg_append  => {
      'proxy_no_cache'     =>'yes',
      'proxy_cache_bypass' =>'yes',
    },
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/flower/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => 'http://flower:8000',
    location_cfg_append  => merge({}, $remote_user_header),
    auth_basic           => $auth_basic,
    auth_basic_user_file => $auth_basic_user_file,
  }

  nginx::resource::location { '/logout':
    server              => $apps::websecmap::hostname,
    ssl                 => true,
    ssl_only            => true,
    www_root            => undef,
    location_cfg_append => {'return' => '401'},
  }

  nginx::resource::location { "${hostname}-maptile-proxy":
    server   => $hostname,
    ssl      => true,
    ssl_only => true,
    www_root => undef,
    location => '/proxy/',
    proxy    => "http://${appname}:8000",
    expires  => '7d',
  }

  file { '/usr/local/bin/websecmap-frontend-clear-cache':
    content => template('apps/websecmap-frontend-clear-cache.erb'),
    mode    => '0744',
  }

  # Zorg Preview
  $auth_basic_preview = 'Please login'
  $auth_basic_preview_user_file = '/etc/nginx/preview.htpasswd'

  nginx::resource::location { '/zorgpreview/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "http://${appname}:8000",
    auth_basic           => $auth_basic_preview,
    auth_basic_user_file => $auth_basic_preview_user_file,
  }

  nginx::resource::location { '/data/map_health/NL/healthcare/':
    server               => $apps::websecmap::hostname,
    ssl                  => true,
    ssl_only             => true,
    www_root             => undef,
    proxy                => "http://${appname}:8000",
    auth_basic           => $auth_basic_preview,
    auth_basic_user_file => $auth_basic_preview_user_file,
  }

  $preview_user = 'preview'
  $preview_password = simplib::passgen('preview_user', {'length' => 32})
  $preview_password_hash = ht_crypt($preview_password, simplib::passgen('htpasswd_seed'))

  file { '/opt/websecmap/secrets/':
    ensure => directory,
    mode   => '0700',
  }

  file { '/opt/websecmap/secrets/preview_user_password':
    content => $preview_password,
    mode    => '0600',
  }

  file { '/etc/nginx/preview.htpasswd':
    content => "${preview_user}:${preview_password_hash}\n",
    owner   => 'www-data',
    group   => root,
    mode    => '0600',
  }
}

