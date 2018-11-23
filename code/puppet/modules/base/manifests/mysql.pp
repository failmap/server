# Customisation for Mysql database
class base::mysql {
  file { '/var/lib/puppet/mysql-apt-config_0.8.9-1_all.deb':
    source => 'puppet:///modules/base/mysql-apt-config_0.8.9-1_all.deb',
  }
  ~> package { 'mysql-apt-config':
    ensure   => latest,
    provider => dpkg,
    source   => '/var/lib/puppet/mysql-apt-config_0.8.9-1_all.deb',
  }
  ~> Exec['apt_update']
  -> Class['mysql::server']
}
