# provide application independent OS layer base settings
class base (
  $localhost_redirects=[],
){
  class { '::cron': }

  class { '::apt': }
  class { '::apt::backports': }

  # utility packages
  package { ['sl', 'atop', 'htop', 'unzip']:
    ensure => latest,
  }

  # add some resource creations for modules not supporting them natively
  create_resources('host', lookup('hosts', Hash, unique, {}))

  # redirects to localhost (mostly used for test suites)
  host { 'localhost-redirects-4':
      host_aliases => $localhost_redirects,
      ip           => '127.0.0.1',
  }
  host { 'localhost-redirects-6':
      host_aliases => $localhost_redirects,
      ip           => '::1',
  }

  # make DNS better managable,
  package { 'resolvconf': ensure => latest}
  ~> service { 'resolvconf': ensure => running, enable => true}
  package { 'dnsmasq': ensure => latest}
  ~> service { 'dnsmasq': ensure => running, enable => true} -> Package['resolvconf']
}
