# setup generic config for nginx/php/mysql sites
class sites (
  $realm=undef,
  $mysql_root_pw=undef,
  $pma=false,
  $pma_allow=[],
  $default_vhost_content='',
){
  # nginx
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
  class {'::php::fpm::daemon': }
  create_resources('php::fpm::conf', hiera_hash('php::fpm::config', {}))

  php::module { [ 'gd', 'mysql']: }

  # dbs
  class { '::mysql::server':
      root_password           => $mysql_root_pw,
      remove_default_accounts => true,
  }

  # default realm vhost
  sites::vhosts::webroot {$realm:
      server_name    => '_',
      listen_options => 'default_server',
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
