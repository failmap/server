# monitoring collection and visualization server
class apps::websecmap::monitoring::server (
  $client_ca=undef,
  $docker_subnet=undef,
  $docker_ip_range=undef,
){
  include ::apps::websecmap

  docker_network { 'monitoring':
    ensure   => present,
    subnet => $docker_subnet,
    ip_range => $docker_ip_range,
  }

  # Influx Time-series database
  Class['docker']
  -> docker::run { 'influxdb':
    # currently disable, not used much and consumes to much resources occasionally
    ensure  => absent,
    running => false,
    image   => influxdb,
    volumes => [
      '/srv/influxdb/data/:/var/lib/influxdb',
      '/srv/influxdb/config.toml:/etc/influxdb/influxdb.conf:ro',
    ],
    net     => monitoring,
    env     => [
      'INFLUXDB_GRAPHITE_ENABLED=true',
    ],
    extra_parameters => "--ip=${apps::websecmap::docker_ip_addresses['influxdb']}",
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
    owner  => 472,
  }
  ~> docker::run { $appname:
    # currently disable, due to not useful without influxdb or other monitoring on server
    ensure  => absent,
    running => false,
    image   => 'grafana/grafana',
    links   => ['influxdb:influxdb'],
    volumes => ['/srv/grafana/:/var/lib/grafana/'],
    net     => monitoring,
    env     => [
      'GF_INSTALL_PLUGINS=grafana-piechart-panel',
      'GF_AUTH_BASIC_ENABLED=false',
      'GF_AUTH_ANONYMOUS_ENABLED=true',
      'GF_AUTH_ANONYMOUS_ORG_ROLE=Editor',
      "GF_SERVER_ROOT_URL=https://admin.${apps::websecmap::hostname}/grafana/",
    ],
    extra_parameters => "--ip=${apps::websecmap::docker_ip_addresses[$appname]}",
  }

  nginx::resource::location { 'admin-grafana':
    server              => "admin.${apps::websecmap::hostname}",
    ssl                 => true,
    ssl_only            => true,
    www_root            => undef,
    proxy               => "http://${apps::websecmap::docker_ip_addresses['grafana']}:3000/",
    location            => '/grafana/',
  }
}
