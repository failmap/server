# configure recent HAproxy service 
class base::haproxy {

  class { 'haproxy':
    package_ensure => latest,
    merge_options  => true,
  }

  # make sure haproxy is installed before triggering renew (and restart of haproxy)
  Class[haproxy] -> Exec['letsencrypt renew']

  # use recent haproxy with resolver support
  apt::pin { '_backports_haproxy':
    packages => ['haproxy', 'libssl1.0.0'],
    priority => 600,
    release  => 'jessie-backports',
  }
  ~> Exec['apt_update']
  -> Package['haproxy']

  package {'hatop': }
}
