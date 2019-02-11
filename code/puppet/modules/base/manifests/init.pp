# provide application independent OS layer base settings
class base (
  Hash[String,Hash] $files = {}
){
  $osinfo = $::os['distro']['description']
  notice("fqdn=${::fqdn}, env=${::env}, os=${osinfo}")

  class { '::apt': }
  class { '::apt::backports': }

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

  file { '/usr/local/bin/failmap-server-update':
    ensure => link,
    target => '/opt/failmap/server/scripts/update.sh',
  }

  file { '/usr/local/bin/failmap-server-apply-configuration':
    content => "#!/bin/bash\nset -e\ncd /opt/failmap/server\n/opt/failmap/server/scripts/apply.sh",
    mode    => '0755',
  }

  # ensure source is present
  file { '/opt/failmap/':
    ensure => directory,
    owner  => root,
    group  => root,
  }
  -> vcsrepo { '/opt/failmap/server/':
    ensure   => present,
    provider => git,
    source   => 'https://gitlab.com/internet-cleanup-foundation/server/',
  }
  # prevent unauthorized access to configuration
  -> file { '/opt/failmap/server/configuration':
    ensure => directory,
    owner  => root,
    group  => sudo,
    mode   => '0750',
  }
}
