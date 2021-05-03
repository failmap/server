# configure message broker
class apps::websecmap::broker (
  Optional[String] $client_ca = undef,
  Optional[String] $tls_combined_path=undef,
  $external_port='1337',
  $internal_port='6379',
  Boolean $enable_remote=false,
  Boolean $enable_insecure_remote=false,
){
  include ::apps::websecmap
  $pod = $apps::websecmap::pod
  $appname = 'broker'

  # expose redis broker container port to external network
  if $enable_insecure_remote {
    $ports = ["${internal_port}:${internal_port}"]

    @firewall { '300 broker incoming insecure external workers (redis)':
      proto  => tcp,
      dport  => $internal_port,
      action => accept,
    }
    @firewall { '300 v6 broker incoming insecure external workers (redis)':
      proto    => tcp,
      dport    => $internal_port,
      action   => accept,
      provider => ip6tables,
    }
  } else {
    $ports = []

    @firewall { '300 broker incoming insecure external workers (redis)':
      ensure => absent,
      proto  => tcp,
      dport  => $internal_port,
      action => accept,
    }
    @firewall { '300 v6 broker incoming insecure external workers (redis)':
      ensure   => absent,
      proto    => tcp,
      dport    => $internal_port,
      action   => accept,
      provider => ip6tables,
    }
  }

  docker::run { $appname:
    image            => redis,
    tag              => latest,
    net              => $pod,
    ports            => $ports,
    extra_parameters => "--ip=${apps::websecmap::hosts[$appname][ip]}",
    env              => ["SERVICE_NAME=${appname}"]
  }

  @telegraf::input { 'broker-redis':
    plugin_type => redis,
    options     => [
      {
        servers => ["tcp://${appname}:6379"]
      },
    ],
  }

  if $client_ca != undef {
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
      ipaddresses       => $apps::websecmap::hosts[$appname][ip],
      options           => 'check resolvers default resolve-prefer ipv4 init-addr last,libc,none',
    }

    # make sure borrowed letsencrypt certificate exists before using it
    Class['Apps::Websecmap::Admin'] -> Class['::Haproxy']

    if $enable_remote {
      $action = accept
    } else {
      $action = reject
    }

    # firewall rule to allow incoming connections
    @firewall { '300 broker incoming external workers (redis,haproxy)':
      proto  => tcp,
      dport  => $external_port,
      action => $action,
    }
    @firewall { '300 v6 broker incoming external workers (redis,haproxy)':
      proto    => tcp,
      dport    => $external_port,
      action   => $action,
      provider => ip6tables,
    }
  }

  ensure_packages(['python3-redis','python3-statsd'], {ensure => latest})
  Exec['apt_update'] -> Package['python3-statsd'] # prevent race condition on vanilla run
  file {'/usr/local/bin/redis-queues.py':
    content => template('apps/redis-queues.py.erb'),
    mode    => '0755',
  }

  file { '/etc/systemd/system/redis-queue-monitor.service':
    content => @("END")
    [Unit]
    Description=Monitor celery redis queue size
    After=systemd-networkd.service
    Requires=systemd-networkd.service
    [Service]
    Type=oneshot
    ExecStart=/usr/bin/python3 /usr/local/bin/redis-queues.py
    TimeoutStartSec=1m
    Environment=BROKER=${appname}
    |END
    ,
    mode    => '0644',
  }

  file { '/etc/systemd/system/redis-queue-monitor.timer':
    content => @(END)
    [Unit]
    Description=Trigger celery redis queue monitor every half minute
    [Timer]
    OnBootSec=30s
    OnUnitActiveSec=30s
    [Install]
    WantedBy=timers.target
    |END
    ,
    mode    => '0644',
  }
  ~> service {'redis-queue-monitor.timer':
    ensure   => running,
    enable   => true,
    provider => systemd,
  }
}
