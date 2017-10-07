# provide application independent OS layer base settings
class base {
  include cron

  # utility packages
  package { ['sl', 'atop', 'htop']:
    ensure => latest,
  }
}
