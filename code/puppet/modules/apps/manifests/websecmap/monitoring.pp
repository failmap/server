# monitoring clients
class apps::websecmap::monitoring {
  include ::apps::websecmap

  docker::run {'monitoring':
    image            => 'quay.io/prometheus/node-exporter',
    tag              => latest,
    command          => join([
      '--path.rootfs=/host',
      '--collector.textfile.directory=/host/var/tmp/node-exporter-textfiles',
      '--collector.systemd',
      # disable metrics about the exporter itself
      '--web.disable-exporter-metrics',
    ],' '),
    net              => host,
    privileged       => true,
    systemd_restart  => 'always',
    extra_parameters => '--pid=host --user=root',
    volumes          => [
      '/:/host:ro,rslave',
      '/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket',
    ],
  }

  docker::run {'statsd':
    image            => 'quay.io/prometheus/statsd-exporter',
    tag              => latest,
    command          => join([
      '--statsd.listen-udp=:8125',
      '--statsd.listen-tcp=:8125',
    ], ' '),
    systemd_restart  => 'always',
    net              => 'websecmap',
    extra_parameters => "--ip=${apps::websecmap::hosts[statsd][ip]}",
  }
}
