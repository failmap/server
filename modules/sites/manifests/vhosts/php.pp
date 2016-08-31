# generic vhost config for PHP site
define sites::vhosts::php (
  $domain=$name,
  $realm=$sites::realm,
  $webroot="/var/www/${name}/html/",
  $source=undef,
  $server_name=$name,
  $listen_options=undef,
  $rewrite_to_https=true,
  $location_allow=undef,
  $location_deny=undef,
  $subdomains=[],
  # http://no-www.org/index.php
  $nowww_compliance='class_b',
){
  include ::sites::php::fpm

  if $server_name == '_' {
    $realm_name = $realm
  } else {
    $realm_host = regsubst($server_name, '\.', '_')
    $realm_name = "${realm_host}.${realm}"
  }

  $certfile = "${::letsencrypt::cert_root}/${server_name}/fullchain.pem"
  $keyfile = "${::letsencrypt::cert_root}/${server_name}/privkey.pem"

  $server_names = concat([], $server_name, $subdomains, $realm_name)

  if $nowww_compliance == 'class_b' {
    $rewrite_www_to_non_www = true
    # make sure letsencrypt has valid config for www. redirect vhosts.
    $le_subdomains = concat($subdomains, prefix(concat([], $server_name, $subdomains), 'www.'))
    $validate_domains = join($server_names, ' ')
    validate_re($validate_domains, '^(?!.*www\.).*$',
        "Class B no-www compliance specified but a wwww. domain in subdomains: ${validate_domains}.")
  }

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
      group  => www-data,
    }
  if $source {
    file { $webroot:
      ensure  => directory,
      owner   => www-data,
      group   => www-data,
      source  => $source,
      recurse => true,
    }
  }

  nginx::resource::vhost { $name:
    server_name            => $server_names,
    www_root               => $webroot,
    index_files            => ['index.php'],
    try_files              => ["\$uri", "\$uri/", '/index.php?$args'],
    listen_options         => $listen_options,
    ssl                    => true,
    ssl_key                => $keyfile,
    ssl_cert               => $certfile,
    rewrite_to_https       => $rewrite_to_https,
    rewrite_www_to_non_www => $rewrite_www_to_non_www,
    location_allow         => $location_allow,
    location_deny          => $location_deny,
    vhost_cfg_append       => {
      'fastcgi_cache'            => 'default',
      'fastcgi_cache_valid'      => '200 30m',
      'access_log'               => "/var/log/nginx/${server_name}.cache.log cache",
      # "if (\$remote_addr == '127.0.0.1')" => "{set \$revalidate 1}",
      'fastcgi_cache_revalidate' => on,
      'expires'                  => '30m',
    }
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
  letsencrypt::domain{ $server_name:
    subdomains => $le_subdomains,
  }
  nginx::resource::location { "letsencrypt_${name}":
    location       => '/.well-known/acme-challenge',
    vhost          => $name,
    location_alias => $::letsencrypt::www_root,
    ssl            => true,
  }
}
