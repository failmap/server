# provide application independent OS layer base settings
class base (
  Hash[String,Hash] $files = {},
  String $source = 'https://gitlab.com/internet-cleanup-foundation/server/',
){
  $osinfo = $::os['distro']['description']
  $codename = $::os['distro']['codename']
  notice("fqdn=${::fqdn}, env=${::env}, os=${osinfo}")

  class { '::apt':
    # make fetching keys work on environments where port 11371 is blocked
    keyserver => 'hkp://keyserver.ubuntu.com:80'
  }

  # still supporting jessie until faalserver is updated
  if $codename == 'jessie' {
    class { '::apt::backports':
      location => 'http://archive.debian.org/debian',
    }
    apt::conf { 'allow-legacy-repos':
      content => 'Acquire::Check-Valid-Until "0";',
    }
  }

  class { 'base::mysql': }

  # utility packages
  package { ['sl', 'atop', 'htop', 'unzip', 'jq', 'cron']:
    ensure => latest,
  }

  file_line {'sudo prompt':
    path     => '/etc/bash.bashrc',
    line     => "PS1='\${debian_chroot:+(\$debian_chroot)}super_\$(logname)@\\h:\\w\\$ '",
    match    => 'PS1=',
    multiple => false,
  }

  class {'base::dns': }

  class {'base::servertool': }

  # use hiera configuration (hiera.yaml) to get a list of classes to include
  # https://puppet.com/docs/puppet/5.2/hiera_use_function.html#examples
  lookup('classes', {merge => unique}).include

  create_resources(file, $files)

  concat { '/etc/motd':
    ensure => present,
  }

  concat::fragment { 'motd banner':
    target  => '/etc/motd',
    content => template('base/motd.erb'),
    order   => '0'
  }

  file {'/etc/banner':
    content => template('base/motd.erb'),
  }

  file { '/usr/local/bin/websecmap-server-update':
    ensure => link,
    target => '/opt/websecmap/server/scripts/update.sh',
  }

  file { '/usr/local/bin/websecmap-server-apply-configuration':
    content => "#!/bin/bash\nset -e\ncd /opt/websecmap/server\n/opt/websecmap/server/scripts/apply.sh",
    mode    => '0755',
  }

  # ensure source is present
  file { '/opt/websecmap/':
    ensure => directory,
    owner  => root,
    group  => root,
  }
  -> vcsrepo { '/opt/websecmap/server/':
    ensure   => present,
    provider => git,
    source   => $source,
  }
  # prevent unauthorized access to configuration
  -> file { '/opt/websecmap/server/configuration':
    ensure => directory,
    owner  => root,
    group  => sudo,
    mode   => '0750',
  }
}
