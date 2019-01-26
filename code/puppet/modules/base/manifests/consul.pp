# configure consul server for service discovery
class base::consul (
){
  Package['unzip']
  -> class { '::consul':
    version       => '0.9.3',
    config_hash   => {
      data_dir         => '/opt/consul',
      log_level        => 'INFO',
      node_name        => $::fqdn,
      server           => true,
      # just run locally, don't assume cluster
      bootstrap_expect => 1,
    },
    extra_options => '--advertise 127.0.0.1 -enable-script-checks',
  }

  # make consul DNS entries resolvable on host system
  File['/etc/dnsmasq.conf']
  -> file { '/etc/dnsmasq.d/consul.conf':
    content => "server=/consul/127.0.0.1#8600\nrev-server=172.17.0.0/16,127.0.0.1#8600",
  }
  ~> Service['dnsmasq']

  Package['resolvconf']
  -> file_line { 'consul search domain':
    line => 'search service.dc1.consul',
    path => '/etc/resolvconf/resolv.conf.d/base',
  } -> Service['resolvconf']
}
