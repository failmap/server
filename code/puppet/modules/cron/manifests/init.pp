# install cron daemon
class cron {
  ensure_packages(['cron'], {ensure => 'present'})
}
