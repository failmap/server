# configure consul server for service discovery
class base::consul (
){
  Package['unzip'] ->
  class { '::consul':
    version       => '0.9.3',
    config_hash   => {
      bootstrap_expect => 1,
      data_dir         => '/opt/consul',
      log_level        => 'INFO',
      node_name        => $::fqdn,
      server           => true,
      # just run locally, don't assume cluster
    },
    extra_options => '--advertise 127.0.0.1',
  }

  # make consul DNS entries resolvable on host system
  Package['dnsmasq'] ->
  file { '/etc/dnsmasq.d/consul.conf':
    content => "server=/consul/127.0.0.1#8600\nrev-server=172.16.0.0/12,127.0.0.1#8600",
  } ~>
  file_line { 'dnsmasq consul forward':
    line => 'conf-dir=/etc/dnsmasq.d/',
    path => '/etc/dnsmasq.conf',
  } ~> Service['dnsmasq']

  Package['resolvconf'] ->
  file_line { 'consul search domain ':
    line => 'search service.dc1.consul',
    path => '/etc/resolvconf/resolv.conf.d/base',
  } -> Service['resolvconf']
}
