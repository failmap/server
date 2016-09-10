# setup generic config for nginx/php/mysql sites
class sites (
  $realm=$::fqdn,
  $mysql_root_pw=undef,
  $pma=false,
  $pma_allow=[],
  $default_vhost_content='',
  $apps_static_php={},
){
  create_resources(apps::static_php, $apps_static_php, {})

  # nginx
  Anchor['nginx::begin'] -> class {'nginx::config':
    fastcgi_cache_path      =>  '/var/www/cache/',
    fastcgi_cache_key       =>  '"$scheme$request_method$host$request_uri"',
    fastcgi_cache_keys_zone =>  'default:250m',
    fastcgi_cache_max_size  =>  '500m',
    fastcgi_cache_inactive  =>  '30m',
    log_format              => {
      cache => '$remote_addr - $upstream_cache_status [$time_local] $request $status $body_bytes_sent $http_referer $http_user_agent',
    }
  }
  class {'nginx': }

  # bugfix: https://github.com/jfryman/puppet-nginx/issues/610
  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>
  Class['::nginx::config'] -> Nginx::Resource::Upstream <| |>

  file { '/var/www/':
      ensure => directory,
  }
  file { '/var/www/cache':
      ensure => directory,
  }

  # certificates
  class { 'letsencrypt': }

  # php related
  php::module { [ 'gd', 'mysql']: }

  # dbs
  class { '::mysql::server':
      root_password           => $mysql_root_pw,
      remove_default_accounts => true,
  }

  # default realm vhost
  sites::vhosts::webroot {$realm:
      default_vhost => true,
  }
  file { "/var/www/${realm}/html/index.html":
    content => $default_vhost_content,
  }

  if $pma {
    # phpmyadmin
    File['/var/www/phpmyadmin/html/'] ->
    class { 'phpmyadmin':
        path    => '/var/www/phpmyadmin/html/pma',
        user    => 'www-data',
        servers => [
            {
                desc => 'local',
                host => '127.0.0.1',
            },
        ],
    }
    sites::vhosts::php{ 'phpmyadmin':
        server_name    => "phpmyadmin.${realm}",
        location_allow => $pma_allow,
        location_deny  => ['all'],
    }
  }
}
