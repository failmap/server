# generic vhost config for PHP site
define sites::vhosts::php (
  $domain=$name,
  $realm=$sites::realm,
  $webroot="/var/www/${name}/html/",
  $server_name=$name,
  $listen_options=undef,
  $rewrite_to_https=true,
  $location_allow=undef,
  $location_deny=undef,
){
  if $server_name == '_' {
    $realm_name = $realm
  } else {
    $realm_host = regsubst($server_name, '\.', '_')
    $realm_name = "${realm_host}.${realm}"
  }

  $certfile = "${::letsencrypt::cert_root}/${server_name}/fullchain.pem"
  $keyfile = "${::letsencrypt::cert_root}/${server_name}/privkey.pem"

  nginx::resource::upstream { $name:
    members => [
      "unix:/var/run/php5-fpm-${name}.sock",
    ],
  }

  Package['nginx'] ->
  php::fpm::conf { $name:
    listen               => "/var/run/php5-fpm-${name}.sock",
    user                 => 'www-data',
    listen_owner         => 'www-data',
    listen_group         => 'www-data',
    pm_max_children      => 3,
    pm_start_servers     => 2,
    pm_min_spare_servers => 1,
    pm_max_spare_servers => 3,
  }

  file {
    "/var/www/${name}/":
      ensure => directory,
      owner  => www-data,
      group  => www-data;
    $webroot:
      ensure => directory,
      owner  => www-data,
      group  => www-data;
  } ->
  nginx::resource::vhost { $name:
    server_name      => [$server_name, $realm_name],
    www_root         => $webroot,
    index_files      => ['index.php'],
    try_files        => ["\$uri", "\$uri/", '/index.php?$args'],
    listen_options   => $listen_options,
    ssl              => true,
    ssl_key          => $keyfile,
    ssl_cert         => $certfile,
    rewrite_to_https => $rewrite_to_https,
    location_allow   => $location_allow,
    location_deny    => $location_deny,
  }

  nginx::resource::location { $name:
    vhost          => $name,
    ssl            => true,
    www_root       => $webroot,
    location       => '~ \.php$',
    fastcgi_params => '/etc/nginx/fastcgi_params',
    fastcgi        => $name,
    try_files      => ['$uri', '$uri/', '/index.php?$args'],
  }

  # configure letsencrypt
  letsencrypt::domain{ $server_name: }
  nginx::resource::location { "letsencrypt_${name}":
    location       => '/.well-known/acme-challenge',
    vhost          => $name,
    location_alias => $::letsencrypt::www_root,
    ssl            => true,
  }
}
