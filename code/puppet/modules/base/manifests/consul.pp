# cleanup remnants of consul configuration
class base::consul (){
  service{'consul':
    ensure   => stopped,
    enable   => false,
    provider => systemd,
  }
  -> file{'/opt/consul':
    ensure => absent,
    force  => true,
  }

  file { '/etc/dnsmasq.d/consul.conf':
    ensure => absent,
  }
  ~> Service['dnsmasq']

  Package['resolvconf']
  -> file_line { 'consul search domain':
    ensure => absent,
    line   => 'search service.dc1.consul',
    path   => '/etc/resolvconf/resolv.conf.d/base',
  }

  service {'dnsmasq':
    ensure => stopped,
    enable => false,
  }

  docker::run {'register':
    ensure => absent,
    image  => 'gliderlabs/registrator:latest',
  }
}