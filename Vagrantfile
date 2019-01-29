# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = ENV['VAGRANT_BOX'] || "debian/jessie64"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4000
    v.cpus = 2
  end

  # enable ipv6
  config.vm.network "private_network", ip: "fde4:8dba:82e1::c4"

  # set hostname which is used to select development settings (hiera/*.yaml)
  config.vm.hostname = "faalserver.faalkaart.test"

  # enable development hostname resolving
  if Vagrant.has_plugin?("landrush")
    config.landrush.enabled = true
    config.landrush.tld = "faalkaart.test"
  end

  config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [
    ".git/",
    ".vagrant/",
    "code/puppet/.gem",
    "code/puppet/vendor",
  ]

  # provision using puppet
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    # improve installation speed by using cache
    export LIBRARIAN_PUPPET_TMP=/vagrant/code/puppet/.tmp

    # install dependencies for Puppet, don't use Vagrant Puppet, we want to test bootstrapping
    /vagrant/scripts/bootstrap.sh

    # apply latests configuration
    SHOW_WARNINGS=1 /vagrant/scripts/apply.sh

    # wait for everthing to be online
    echo "Waiting for failmap to be online before starting tests."
    timeout 30 /bin/sh -c 'while sleep 1; do curl -sSvk https://faalkaart.test 2>/dev/null | grep MSPAINT >/dev/null && exit 0; done'
    SHELL

  # run serverspec as a provisioner to test the previously provisioned machine
  config.vm.provision :serverspec do |spec|
    # pattern for specfiles to search
    spec.pattern = 'tests/serverspec/*.rb'
  end

  config.vm.post_up_message = "Tell people to visit http://faalkaart.faalserver.test"
end
