# monitoring clients
class apps::websecmap::monitoring {
  include ::apps::websecmap

  class { '::collectd':
    # disabled due to influxdb being disabled
    service_enable  => false,
    service_ensure  => stopped,
    purge           => true,
    recurse         => true,
    purge_config    => true,
    minimum_version => '5.7',
    manage_repo     => false,
    package_ensure  => latest,
  }

  collectd::plugin::write_graphite::carbon {'influxdb':
    graphitehost   => 'influxdb.service.dc1.consul',
    graphiteport   => 2003,
    graphiteprefix => '',
    protocol       => 'tcp'
  }

  # default plugins
  class { '::collectd::plugin::cpu':
    # aggregate cpu stats into one metric
    reportbycpu => false,
  }
  class { '::collectd::plugin::df':
    # ignore disk size metrics of special type disks (/dev, /proc, etc)
    fstypes          => ['nfs','tmpfs','autofs','gpfs','proc','devpts', 'devtmpfs', 'aufs'],
    ignoreselected   => true,
    valuespercentage => true,
  }
  class { '::collectd::plugin::disk': }
  class { '::collectd::plugin::interface':
    # ignore virtual/container interfaces (eg: docker)
    interfaces     => ['/.*-.*/'],
    ignoreselected => true,
  }
  class { '::collectd::plugin::load':
    report_relative => true,
  }
  class { '::collectd::plugin::memory':
    valuespercentage => true,
  }
  class { '::collectd::plugin::processes': }
  class { '::collectd::plugin::swap': }
  class { '::collectd::plugin::users': }

  # realise virtual resources
  Collectd::Plugin::Tail::File <| |>

  class { '::telegraf':
    # disabled due to influxdb being disabled
    service_enable     => false,
        service_ensure => stopped,
    hostname           => $::hostname,
    outputs            => {
      influxdb => [
        {
          urls     => [ 'http://influxdb.service.dc1.consul:8086' ],
          database => telegraf,
        }
      ]
    },
    inputs             => {
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
