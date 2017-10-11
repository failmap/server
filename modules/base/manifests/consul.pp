# configure consul server for service discovery
class base::consul (
  $dc = dc1,
){
  Package['unzip'] ->
  class { '::consul':
    version       => '0.9.3',
    config_hash   => {
      bootstrap_expect => 1,
      data_dir         => '/opt/consul',
      datacenter       => $dc,
      log_level        => 'INFO',
      node_name        => $::fqdn,
      server           => true,
      # just run locally, don't assume cluster
    },
    extra_options => '--advertise 127.0.0.1',
  }
}
