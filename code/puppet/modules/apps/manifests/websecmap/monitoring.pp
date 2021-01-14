# monitoring clients
class apps::websecmap::monitoring {
  include ::apps::websecmap

  class { '::telegraf':
  service_enable   => true,
    service_ensure => running,
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
      consul        => [{}],
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

  # collect and instantiate telegraf inputs defined elsewhere with @telegraf::input
  Telegraf::Input <| |>
}
