# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/jessie64"

  # enable ipv6
  config.vm.network "private_network", ip: "fde4:8dba:82e1::c4"

  # enable development hostname resolving
  config.landrush.enabled = true
  config.landrush.tld = "faalkaart.test"
  config.vm.hostname = "faalserver"

  # ensure virtualbox shared folders are used
  # debian box does not have vbguest extensions by default (install vagrant-vbguest plugin)
  # and will default to rsync instead, which is broken and a less seamless experience
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # provision using puppet
  config.vm.provision "shell", inline: <<-SHELL
    /vagrant/scripts/bootstrap.sh || exit 1
    /vagrant/scripts/apply.sh || exit 1
  SHELL

  # testsuite
  config.vm.provision "shell", inline: <<-SHELL
    /vagrant/scripts/install_sslscan.sh || exit 1
    /vagrant/scripts/test.sh || exit 1
  SHELL

end