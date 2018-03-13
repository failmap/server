# manage DNS related configuration
class base::dns (
  $localhost_redirects=[],
){
  # create host entries from hiera configuration
  create_resources('host', lookup('hosts', Hash, unique, {}))

  # create redirects to localhost (mostly used for test suites)
  host { 'localhost-redirects-4':
      host_aliases => $localhost_redirects,
      ip           => '127.0.0.1',
  }
  host { 'localhost-redirects-6':
      host_aliases => $localhost_redirects,
      ip           => '::1',
  }

  # make DNS better managable,
  package { 'dnsmasq': ensure => latest}
  ~> service { 'dnsmasq': ensure => running, enable => true}
  -> package { 'resolvconf': ensure => latest}
  ~> service { 'resolvconf': ensure => running, enable => true}

  # race conditions cause DNS services to be unavailable during package installs.
  # Postpone DNS config until every other package is installed.
  Package <| title != dnsmasq and title != resolvconf |> -> Package['resolvconf']
}
