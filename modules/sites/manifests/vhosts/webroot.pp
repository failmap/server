# vhost just serving static content
define sites::vhosts::webroot (
  $domain=$name,
  $realm=$sites::realm,
  $webroot="/var/www/${name}/html/",
  $server_name=$name,
  $listen_options=undef,
  $rewrite_to_https=true,
  $location_allow=undef,
  $location_deny=undef,
  $subdomains=[],
  # http://no-www.org/index.php
  $nowww_compliance='class_b',
  $expires='10m',
  $static_expires='30d',
){
  if $server_name == '_' {
    $realm_name = $realm
    $letsencrypt_name = $realm
  } else {
    $realm_host = regsubst($server_name, '\.', '_')
    $realm_name = "${realm_host}.${realm}"
    $letsencrypt_name = $server_name
  }

  $certfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/fullchain.pem"
  $keyfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/privkey.pem"

  $server_names = concat([], $server_name, $subdomains, $realm_name)

  if $nowww_compliance == 'class_b' {
    $rewrite_www_to_non_www = true
    # make sure letsencrypt has valid config for www. redirect vhosts.
    $le_subdomains = concat($subdomains, prefix(concat([], $letsencrypt_name, $subdomains), 'www.'))
    $validate_domains = join($server_names, ' ')
    validate_re($validate_domains, '^(?!.*www\.).*$',
        "Class B no-www compliance specified but a wwww. domain in subdomains: ${validate_domains}.")
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
    index_files      => ['index.html'],
    listen_options   => $listen_options,
    ssl              => true,
    ssl_key          => $keyfile,
    ssl_cert         => $certfile,
    rewrite_to_https => $rewrite_to_https,
    location_allow   => $location_allow,
    location_deny    => $location_deny,
    vhost_cfg_append => {
      'expires' => $expires,
    }
  }

  # disable exposing php files
  nginx::resource::location { "${name}-php":
    vhost         => $name,
    ssl           => true,
    www_root      => $webroot,
    location      => '~ \.php$',
    location_deny => ['all'],
  }

  # cache static files a lot
  nginx::resource::location { "${name}-static_cache":
    vhost            => $name,
    ssl              => true,
    www_root         => $webroot,
    location         => '~* \.(?:ico|css|js|gif|jpe?g|png)$',
    location_cfg_append => {
      'expires' => $static_expires,
    }
  }

  # configure letsencrypt
  letsencrypt::domain{ $letsencrypt_name:
    subdomains => $le_subdomains,
  }
  nginx::resource::location { "letsencrypt_${name}":
    location       => '/.well-known/acme-challenge',
    vhost          => $name,
    location_alias => $::letsencrypt::www_root,
    ssl            => true,
  }
}
