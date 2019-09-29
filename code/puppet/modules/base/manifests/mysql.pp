# Customisation for Mysql database
class base::mysql {
  # on systems with mysql (eg: Debian 8) install a more recent version of mysql
  file { '/var/lib/puppet/mysql-apt-config_0.8.13-1_all.deb':
    source => 'puppet:///modules/base/mysql-apt-config_0.8.13-1_all.deb',
  }
  ~> package { 'mysql-apt-config':
    ensure   => latest,
    provider => dpkg,
    source   => '/var/lib/puppet/mysql-apt-config_0.8.13-1_all.deb',
  }
  ~> Exec['apt_update']
  -> [Class['mysql::server'], Class['mysql::client']]
}
