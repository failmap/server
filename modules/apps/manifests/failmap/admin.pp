# Configure the Admin frontend as well as the basic service requirements (database, queue broker)
class apps::failmap::admin {
  include common

  $hostname = 'admin.faalkaart.nl'
  $appname = 'failmap-admin'

  $db_name = 'failmap'
  $db_user = $db_name

  # database
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")
  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => 'localhost',
    grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
  }

  $secret_key = fqdn_rand_string(32, '', "${random_seed}secret_key")
  docker::run { $appname:
    image   => 'registry.gitlab.com/failmap/admin:latest',
    command => 'runuwsgi',
    volumes => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env     => [
      'DB_ENGINE=mysql',
      'DB_HOST=/var/run/mysqld/mysqld.sock',
      "DB_NAME=${db_name}",
      "DB_USER=${db_user}",
      "DB_PASSWORD=${db_password}",
      "SECRET_KEY=${secret_key}",
      "ALLOWED_HOSTS=${hostname}",
    ]
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.docker:8000",
    nowww_compliance => class_c,
  }
}
