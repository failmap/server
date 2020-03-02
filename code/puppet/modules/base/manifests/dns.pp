# manage DNS related configuration
class base::dns (
  $localhost_redirects=[],
){
  # create host entries from hiera configuration
  create_resources(host, lookup(hosts, Hash, hash, {}))

  # create redirects to localhost (mostly used for test suites)
  host { 'localhost-redirects-4':
      host_aliases => $localhost_redirects,
      ip           => '127.0.0.1',
  }
  host { 'localhost-redirects-6':
      host_aliases => $localhost_redirects,
      ip           => '::1',
  }

  package { 'resolvconf': ensure => latest}
}
