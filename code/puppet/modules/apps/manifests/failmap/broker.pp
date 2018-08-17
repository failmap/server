# configure message broker
class apps::failmap::broker (
  $pod = $apps::failmap::pod,
  String $client_ca = undef,
  $external_port='1337',
  $internal_port='6379',
  String $tls_combined_path=undef,
  Boolean $enable_remote=false,
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
        servers => ["tcp://${appname}:6379"]
      },
    ],
  }

  $client_ca_path = "/etc/ssl/certs/haproxy-client-ca-${appname}.pem"
  file { $client_ca_path:
    content => $client_ca,
  }
  -> ::Haproxy::Instance[haproxy]

  include ::base::haproxy

  haproxy::listen { 'broker':
    collect_exported => false,
    mode             => tcp,
    options          => {
      timeout => [
        'client 60m',
        'server 60m',
      ],
    },
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
    server_names      => $appname,
    ipaddresses       => "${appname}.service.dc1.consul",
    options           => 'check resolvers default resolve-prefer ipv4 init-addr last,libc,none',
  }

  # make sure borrowed letsencrypt certificate exists before using it
  Class['Apps::Failmap::Admin'] -> Class['::Haproxy']

  if $enable_remote {
    $action = accept
  } else {
    $action = reject
  }

  # firewall rule to allow incoming connections
  @firewall { '300 broker incoming external workers (redis,haproxy)':
    proto  => tcp,
    port   => $external_port,
    action => $action,
  }
  @firewall { '300 v6 broker incoming external workers (redis,haproxy)':
    proto    => tcp,
    port     => $external_port,
    action   => $action,
    provider => ip6tables,
  }

  ensure_packages(['python3-redis','python3-statsd'], {ensure => latest})
  Exec['apt_update'] -> Package['python3-statsd'] # prevent race condition on vanilla run
  file {'/usr/local/bin/redis-queues.py':
    content => template('apps/redis-queues.py.erb')
  }
  ~> Service['redis-queue-monitor']

  file { '/etc/systemd/system/redis-queue-monitor.service':
    content => @("END")
    [Unit]
    Description=Monitor celery redis queue size
    After=systemd-networkd.service
    Requires=systemd-networkd.service

    [Service]
    ExecStart=/usr/bin/python3 /usr/local/bin/redis-queues.py
    Environment=BROKER=${appname}
    RestartSec=5s
    Restart=always

    [Install]
    WantedBy=multi-user.target
    |END
    ,
    mode    => '0644',
  }
  ~> service {'redis-queue-monitor':
    ensure => running,
    enable => true,
  }

}
