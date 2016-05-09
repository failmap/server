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
    }

    # configure letsencrypt
    letsencrypt::domain{ $letsencrypt_name: }
    nginx::resource::location { "letsencrypt_${name}":
    location       => '/.well-known/acme-challenge',
    vhost          => $name,
    location_alias => $::letsencrypt::www_root,
    ssl            => true,
  }
}
