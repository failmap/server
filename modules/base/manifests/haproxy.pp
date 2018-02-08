# configure recent HAproxy service with support for consul service resolving
class base::haproxy {

  class { 'haproxy':
    package_ensure => latest,
    merge_options  => true,
  }

  # use recent haproxy with resolver support
  apt::pin { '_backports_haproxy':
    packages => ['haproxy', 'libssl1.0.0'],
    priority => 600,
    release  => 'jessie-backports',
  }
  ~> Exec['apt_update']
  -> Package['haproxy']

  # configure haproxy to use dnsmasq resolver which allow querying consul service records
  haproxy::resolver { 'default':
    nameservers     => {
      'dns1' => '127.0.0.1:53',
    },
    hold            => {
      'nx'    => '30s',
      'valid' => '10s'
    },
    resolve_retries => 3,
    timeout         => {
      'retry' => '1s'
    },
  }
}
