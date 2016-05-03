# create nginx vhost, php-fpm server, database and clone website git repo
class sites::faalkaart(
  $db_user='faalkaart',
  $db_password='kaartfaal',
  $db_name='faalkaart',
){
  ensure_packages(['git'], {'ensure' => 'present'})

  # configure vhost and clone source into webroot
  sites::vhosts::php { 'faalkaart.nl':
    source => 'puppet:///modules/sites/faalkaart/html',
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

  file { '/var/www/faalkaart.nl/configuration.php':
    owner   => 'www-data',
    group   => 'www-data',
    content => template('sites/faalkaart.configuration.php.erb')
  }
}
