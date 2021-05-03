# resources shared by frontend, admin and workers
class apps::websecmap (
  $hostname='default',
  $pod='websecmap',
  $ipv6_subnet=undef,
  $image='websecmap/websecmap:latest',
  $broker='redis://broker:6379/0',
  $db_name='websecmap',
  # lookup table of internal container ip addresses for nginx
  $docker_subnet=undef,
  $docker_ip_range=undef,
){
  $hosts = lookup(hosts, Hash, hash, {})
  $hostentries = $hosts.map | $index,$value | { "${index}:${value[ip]}"}

  if $ipv6_subnet {
    $network_opts = "--subnet=${docker_subnet} --ip-range=${docker_ip_range} --ipv6 --subnet=${ipv6_subnet}"
  } else {
    $network_opts = "--subnet=${docker_subnet} --ip-range=${docker_ip_range}"
  }

  # create application group network before starting containers
  Service['docker']
  -> exec { "${pod} docker network":
    command => "/usr/bin/docker network create ${network_opts} ${pod}",
    unless  => "/usr/bin/docker network inspect ${pod}",
  } -> Docker::Run <| |>

  # stateful configuration (credentials for external parties, eg: Sentry)
  file {
    "/srv/${pod}":
      ensure => directory,
      mode   => '0700';
    "/srv/${pod}/env.file":
      ensure => present;
  } -> Docker::Run <| |>

  # temporary solution for storing screenshots for live release
  file {
    '/srv/websecmap/images/':
      ensure => directory;
    '/srv/websecmap/images/screenshots/':
      ensure => directory;
  }

  # fix issue with container not restarting anymore after being restarted to often in a short timespan
  systemd::dropin_file { 'no-restart-limit.conf':
    unit    => 'docker-websecmap-.service',
    content => @("END"),
    [Unit]
    # disable a limit on restarts
    StartLimitIntervalSec=0
    [Service]
    # prevent services from restarting to fast and causing high load
    RestartSec=10
    |END
  }
  # since systemd 239 is not running on 18.04, fake it
  ~> exec {'symlink override for all containers':
    command     => '/bin/ls /etc/systemd/system/docker-websecmap-*.service \
    | /usr/bin/xargs -n1 -I% ln -fs /etc/systemd/system/docker-websecmap-.service.d %.d',
    refreshonly => true,
  } ~> Class[Systemd::Systemctl::Daemon_reload]

  Docker::Run <| |> ~> Exec['symlink override for all containers']
}
