uwsgi services either

x using python virtualenvs and systemd instantiated services (https://coreos.com/os/docs/latest/getting-started-with-systemd.html#instantiated-units)
  - requires build
  - less flexible

v using containers
  - requires docker

- puppet-docker requires systemd (dbus) access to start containers
  - run systemd inside container
  - sysadm cap?

- consul als container registry met dns api
https://gliderlabs.com/registrator/latest/
https://docs.docker.com/samples/library/consul/#service-discovery-with-containers

https://github.com/garethr/puppet-docker-example/blob/master/Puppetfile
https://forge.puppet.com/KyleAnderson/consul

- nginx queries consul
  - andere dns oplossingen gebruiken udp, niet compatible met nginx
  - eventueel dnsmasq ervoor?
  - eerst even consul proberen want leerzaam
