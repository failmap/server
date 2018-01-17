# monitoring collection and visualization server
class base::monitoring::server (
  $client_ca=undef,
){
  # Influx Time-series database
  Class['docker'] ->
  docker::run { 'influxdb':
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
  file { '/srv/influxdb/': ensure => directory } ->
  Package['docker'] -> Exec['generate initial influxdb config']
  exec {'generate initial influxdb config':
    command => '/usr/bin/docker run --rm influxdb influxd config > /srv/influxdb/config.toml',
    creates => '/srv/influxdb/config.toml',
  } ->
  file_line { 'influx graphite template':
    line    => "  templates = [${templates}]",
    path    => '/srv/influxdb/config.toml',
    after   => '\[\[graphite\]\]',
    replace => true,
    match   => templates,
  } ~> Docker::Run['influxdb']

  # Grafana Graphing frontend
  $appname = grafana
  $hostname = "${appname}.faalkaart.nl"

  docker::run { $appname:
    image   => 'grafana/grafana',
    links   => ['influxdb:influxdb'],
    volumes => ['/srv/grafana/:/var/lib/grafana/'],
    env     => [
      "GF_SERVER_ROOT_URL=https://${hostname}",
      'GF_INSTALL_PLUGINS=grafana-piechart-panel',
    ],
  }

  sites::vhosts::proxy { $hostname:
    proxy            => "${appname}.service.dc1.consul:3000",
    nowww_compliance => class_c,
    # use consul as proxy resolver
    resolver         => ['127.0.0.1:8600'],
    # require client certificate for access
    client_ca        => $client_ca,
  }
}
