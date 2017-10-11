# provide application independent OS layer base settings
class base (
  $localhost_redirects=[],
){
  include cron

  # utility packages
  package { ['sl', 'atop', 'htop', 'unzip']:
    ensure => latest,
  }

  # add some resource creations for modules not supporting them natively
  create_resources('host', hiera_hash('hosts', {}))

  # redirects to localhost (mostly used for test suites)
  host { 'localhost-redirects-4':
      host_aliases => $localhost_redirects,
      ip           => '127.0.0.1',
  }
  host { 'localhost-redirects-6':
      host_aliases => $localhost_redirects,
      ip           => '::1',
  }
}
