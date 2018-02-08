# configure message broker
class apps::failmap::broker (
  $pod = $apps::failmap::pod,
  $client_ca = undef,
  $external_port='1337',
  $internal_port='6379',
  String $tls_combined_path=undef,
){
  $appname = 'broker'

  docker::run { $appname:
    image => redis,
    tag   => latest,
    net   => $pod,
    env   => ["SERVICE_NAME=${appname}"]
  }

  @telegraf::input { 'broker-redis':
    plugin_type => redis,
    options     => [
      {
        servers => ['tcp://redis:6379']
      },
    ],
  }

  $client_ca_path = "/etc/ssl/certs/haproxy-client-ca-${appname}.pem"
  file { $client_ca_path:
    content => $client_ca,
  }

  include base::haproxy

  haproxy::listen { 'broker':
    collect_exported => false,
    bind             => {
      "0.0.0.0:${external_port}" => [
        # use TLS for connection
        'ssl', 'crt', $tls_combined_path,
        # require client certificate
        'verify', 'required', 'ca-file', $client_ca_path,
      ]
    },
  }
  haproxy::balancermember { 'broker':
    listening_service => 'broker',
    ports             => $internal_port,
    server_names      => "${appname}.service.dc1.consul",
    ipaddresses       => "${appname}.service.dc1.consul",
    options           => 'check resolvers default resolve-prefer ipv4 init-addr last,libc,none',
  }

  # make sure borrowed letsencrypt certificate exists before using it
  Letsencrypt::Domain['faalkaart.nl'] -> Haproxy::Listen[broker]

  # firewall rule to allow incoming connections
  @firewall { '300 broker incoming external workers (redis,haproxy)':
    proto  => tcp,
    port   => $external_port,
    action => accept,
  }
  @firewall { '300 v6 broker incoming external workers (redis,haproxy)':
    proto    => tcp,
    port     => $external_port,
    action   => accept,
    provider => ip6tables,
  }
}
