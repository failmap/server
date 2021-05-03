# monitoring clients
class apps::websecmap::monitoring {
  include ::apps::websecmap

  class { '::telegraf':
    service_enable => false,
    service_ensure => stopped,
    hostname       => $::hostname,
    outputs        => {
      prometheus_client => [{}],
    },
    inputs         => {
      statsd        => [{
        templates => [
          # websecmap.celery.websecmap.scanners.scanner_security_headers.get_headers.sent
          '*.celery.* prefix.measurement.project.app.module.task.measurement*',
          # websecmap.db.mysql.default_execute_insert
          '*.db.* prefix.measurement.engine.database.measurement*',
          # websecmap.response_auth.200
          '*.response.* prefix.measurement.*',
          # websecmap.view.websecmap.map.views.topwin.GET
          '*.view.*.*.*.*.* prefix.measurement.project.app.module.view.measurement',
          # websecmap.view.proxy.views.proxy_view.GET
          '*.view.*.*.*.* prefix.measurement.app.module.view.measurement',
          # websecmap.view.proxy.views.GET
          '*.view.*.*.* prefix.measurement.app.module.measurement',
        ]
      }],
      system        => [{}],
      net           => [{}],
      netstat       => [{}],
      mem           => [{}],
      disk          => [{}],
      diskio        => [{}],
      processes     => [{}],
      kernel        => [{}],
      kernel_vmstat => [{}],
    },
  }

  Package[telegraf]
  -> exec { 'telegraf docker permissions':
    unless  => '/usr/bin/id -nG telegraf | grep docker',
    command => '/usr/sbin/usermod -aG docker telegraf',
  }

  Service {
    provider => systemd,
  }

  # collect and instantiate telegraf inputs defined elsewhere with @telegraf::input
  Telegraf::Input <| |>

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
    extra_parameters => '--pid=host --user=root',
    volumes          => [
      '/:/host:ro,rslave',
      '/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket',
    ],
  }
}
