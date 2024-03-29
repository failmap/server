# application independent generic docker daemon configuration
class base::docker (
  $ipv6_subnet=undef,
  $ipv6_ndpproxy=undef
){
  if $ipv6_subnet {
    $ipv6_parameters = ['--ipv6', "--fixed-cidr-v6=${ipv6_subnet}"]
  } else {
    $ipv6_parameters = []
  }

  class {'::docker':
    extra_parameters => $ipv6_parameters,
  }

  cron { 'docker garbage collection':
    # TODO: investigate bug in docker that removes tags on running container images
    command => '/usr/bin/docker system prune  --force --all --volumes',
    hour    => 18,
    minute  => 0,
    weekday => 0,
  }

  # include cleanup of old consul configuration
  include base::consul

  # enable memory accounting for `docker stats`
  # http://awhitehatter.me/debian-jessie-wdocker/
  if ::lsbdistcodename == 'jessie' {
    file_line {'docker memory stats':
      line    => 'GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=memory swapaccount=1"',
      match   => 'GRUB_CMDLINE_LINUX_DEFAULT',
      replace => true,
      path    => '/etc/default/grub',
    } ~> exec {'update grub':
      command     => '/usr/sbin/update-grub',
      refreshonly => true,
    }
  }

  if $ipv6_ndpproxy {
    $ndproxy_interface = $::networking['primary']
    file { '/var/run/ndppd':
      ensure => directory,
    }
    file { '/var/lib/puppet/ndppd_0.2.5-1_amd64.deb':
      source => 'puppet:///modules/base/ndppd_0.2.5-1_amd64.deb',
    }
    ~> package {'ndppd':
      ensure   => latest,
      provider => dpkg,
      source   => '/var/lib/puppet/ndppd_0.2.5-1_amd64.deb',
    }
    -> file { '/etc/ndppd.conf':
      content => template('base/ndppd.conf.erb'),
    }
    ~> service {'ndppd':
      ensure   => running,
      enable   => true,
      provider => systemd,
    }

    # fix where pid directory does not exist after boot
    file {
      '/etc/systemd/system/ndppd.service.d/':
      ensure => directory;
      '/etc/systemd/system/ndppd.service.d/var-run-ndppd.conf':
      content => "[Service]\nExecStartPre=-/bin/mkdir -p /var/run/ndppd/\n",
    }
    ~> [Service['ndppd'], Class[Systemd::Systemctl::Daemon_reload]]
  }
}

