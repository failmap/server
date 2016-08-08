# create nginx vhost, php-fpm server, database and clone website git repo
class sites::faalkaart(
  $db_user='faalkaart',
  $db_password='kaartfaal',
  $db_name='faalkaart',
){
  ensure_packages(['git'], {'ensure' => 'present'})

  # configure vhost and clone source into webroot
  sites::vhosts::php { 'faalkaart.nl':
    source => undef,
  }

  # create database
  # create wordpress DB
  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => 'localhost',
    grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
    sql      => '/var/backups/mysql/faalkaart.nl.sql',
  }

  vcsrepo { '/var/www/faalkaart.nl/':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/failmap/website.git',
    revision => master,
    force    => true,
  } ->
  file { '/var/www/faalkaart.nl/configuration.php':
    owner   => 'www-data',
    group   => 'www-data',
    content => template('sites/faalkaart.configuration.php.erb')
  }

  cron { 'cache-warming':
    command => '/usr/bin/curl -ks -Hhost:faalkaart.nl https://localhost 2>&1 >/dev/null',
  }

}
