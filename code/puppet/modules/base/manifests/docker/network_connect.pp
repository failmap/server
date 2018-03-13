# resource to maintain container network connection
define base::docker::network_connect () {
  $x = split($title, '@')
  $network = $x[0]
  $container = $x[1]

  $command = "/usr/bin/docker network connect ${network} ${container}"
  $check = "/usr/bin/docker network inspect -f '{{range .Containers}} \
            {{.Name}} {{end}}' ${network}| /bin/grep -w ${container}"

  # create container connection if it doesn't exist
  exec { $command:
    command => $command,
    unless  => $check,
  }

  # ensure network is created after required resources exist
  Docker_network[$network] -> Exec[$command]
  Docker::Run[$container] -> Exec[$command]
}
