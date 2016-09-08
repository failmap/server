# create nginx vhost, php-fpm server, database and clone website git repo
class sites::faalkaart(
  $db_user='faalkaart',
  $db_password='kaartfaal',
  $db_name='faalkaart',
){
  package { 'php5-cli': }
  include ::base::cron

  ensure_packages(['git'], {'ensure' => 'present'})

  # configure vhost
  sites::vhosts::webroot { 'faalkaart.nl': }

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
    owner    => www-data,
    group    => www-data,
  } ->
  file { '/var/www/faalkaart.nl/configuration.php':
    owner   => 'www-data',
    group   => 'www-data',
    content => template('sites/faalkaart.configuration.php.erb')
  }

  # generate index.html for index.php file every 10 minutes.
  cron { 'failmap-static-generation':
    command => 'cd /var/www/faalkaart.nl/html/; /usr/bin/php index.php > index.html',
    minute  => '*/10',
    user    => 'www-data',
  }

  Package['php5-cli'] ->
  exec { 'initial generate':
    command => '/usr/bin/php index.php > index.html',
    cwd     => '/var/www/faalkaart.nl/html/',
    creates => '/var/www/faalkaart.nl/html/index.html',
    user    => 'www-data',
  }
}
