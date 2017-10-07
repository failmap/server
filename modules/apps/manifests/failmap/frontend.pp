# Configure the failmap frontend
class apps::failmap::frontend (
  $hostname = 'faalkaart.nl'
){
  include common

  $appname = 'failmap-frontend'

  $db_name = 'failmap'
  $db_user = "${db_name}ro"

  # database readonly user
  $random_seed = file('/var/lib/puppet/.random_seed')
  $db_password = fqdn_rand_string(32, '', "${random_seed}${db_user}")
  mysql_user { "${db_user}@localhost":
    password_hash => mysql_password($db_password),
  } ->
  mysql_grant { "${db_user}@localhost/${db_name}.*":
    user       => "${db_user}@localhost",
    table      => "${db_name}.*",
    privileges => ['SELECT'],
  }

  docker::run { $appname:
    image   => 'registry.gitlab.com/failmap/admin:latest',
    command => 'runuwsgi',
    volumes => [
      '/var/run/mysqld/mysqld.sock:/var/run/mysqld/mysqld.sock',
    ],
    env     => {
      'DB_ENGINE'     => mysql,
      'DB_HOST'       => '/var/run/mysqld/mysqld.sock',
      'DB_NAME'       => $db_name,
      'DB_USER'       => $db_user,
      'DB_PASSWORD'   => $db_password,
      'SECRET_KEY'    => fqdn_rand_string(32, '', "${random_seed}secret_key"),
      'ALLOWED_HOSTS' => $hostname,
    }
  }
  # ensure containers are up before restarting nginx
  # https://gitlab.com/failmap/server/issues/8
  Docker::Run[$appname] -> Service['nginx']

  sites::vhosts::proxy { $hostname:
    proxy => "${appname}.docker:8000",
  }
}
