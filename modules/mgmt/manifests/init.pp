# install and manage mgmt config
class mgmt {
  file { '/usr/local/bin/mgmt':
    source => 'puppet:///modules/mgmt/mgmt-linux-amd64',
    mode   => '0755',
  }

  file { '/etc/systemd/system/mgmt.service':
    source => 'puppet:///modules/mgmt/mgmt.service',
    mode   => '0644',
  }
  ~> service {'mgmt':
    ensure => stopped,
    enable => false,
  }
}
