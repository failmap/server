# monitoring collection and visualization server
class apps::websecmap::monitoring::server (
  $client_ca=undef,
){
  include ::apps::websecmap

  # Influx Time-series database
  Class['docker']
  -> docker::run { 'influxdb':
    image   => influxdb,
    volumes => [
      '/srv/influxdb/data/:/var/lib/influxdb',
      '/srv/influxdb/config.toml:/etc/influxdb/influxdb.conf:ro',
    ],
    env     => [
      'INFLUXDB_GRAPHITE_ENABLED=true',
    ]
  }

  $templates = join(prefix(suffix([
    'server.measurement*',
  ], '"'), '"'), ',')
  file { '/srv/influxdb/': ensure => directory }
  -> Package['docker'] -> Exec['generate initial influxdb config']
  exec {'generate initial influxdb config':
    command => '/usr/bin/docker run --rm influxdb influxd config > /srv/influxdb/config.toml',
    creates => '/srv/influxdb/config.toml',
  }
  -> file_line { 'influx graphite template':
    line    => "  templates = [${templates}]",
    path    => '/srv/influxdb/config.toml',
    after   => '\[\[graphite\]\]',
    replace => true,
    match   => templates,
  } ~> Docker::Run['influxdb']

  # Grafana Graphing frontend
  $appname = grafana

  file { '/srv/grafana':
    ensure => directory,
    # http://docs.grafana.org/installation/docker/#user-id-changes
    owner => 472,
  }
  ~> docker::run { $appname:
    image   => 'grafana/grafana',
    links   => ['influxdb:influxdb'],
    volumes => ['/srv/grafana/:/var/lib/grafana/'],
    env     => [
      "GF_SERVER_ROOT_URL=https://admin.${apps::websecmap::hostname}/grafana/",
      "GF_SERVER_DOMAIN=admin.${apps::websecmap::hostname}",
      'GF_INSTALL_PLUGINS=grafana-piechart-panel',
      'GF_AUTH_ANONYMOUS_ENABLED=true',
      'GF_AUTH_ANONYMOUS_ORG_ROLE=Editor',
    ],
  }

  nginx::resource::location { 'admin-grafana':
    server   => "admin.${apps::websecmap::hostname}",
    ssl      => true,
    ssl_only => true,
    www_root => undef,
    proxy                => "\$backend",
    location_cfg_append  => {
      'set $backend' => 'http://grafana.service.dc1.consul:3000',
    },
    location => '/grafana/',
  }
}
