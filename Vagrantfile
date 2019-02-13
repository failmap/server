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

  config.vm.define "default", primary: true do |config|
    # set hostname which is used to select development settings (hiera/*.yaml)
    config.vm.hostname = "faalserver.faalkaart.test"

    # provision using puppet
    config.vm.provision "shell", inline: <<-SHELL
      set -e
      # improve installation speed by using cache
      export LIBRARIAN_PUPPET_TMP=/vagrant/code/puppet/.tmp

      # install dependencies for Puppet, don't use Vagrant Puppet, we want to test bootstrapping
      /vagrant/scripts/bootstrap.sh

      # apply latests configuration
      SHOW_WARNINGS=1 /vagrant/scripts/apply.sh
      SHELL

    config.vm.provision "shell", inline: <<-SHELL
      # wait for everthing to be online
      echo "Waiting up to 30 seconds for websecmap to be online before starting tests."
      timeout 30 /bin/sh -c 'while sleep 1; do curl -sSvk https://faalkaart.test 2>/dev/null | grep MSPAINT >/dev/null && exit 0; done'
      SHELL

      # run serverspec as a provisioner to test the previously provisioned machine
    config.vm.provision :serverspec do |spec|
      # pattern for specfiles to search
      spec.pattern = 'tests/serverspec/{base,frontend,frontend-nowww}.rb'
    end
  end

  config.vm.define "install.sh" do |config|
    config.vm.hostname = "example.com"

    config.vm.provision "shell", inline: <<-SHELL
      set -e

      # the source is copied to the VM using rsync, the install.sh script expects to clone from a repository
      # convert the copied source into a makeshift repository. (copying .git/ allong with the source costs more)
      apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -yqq git >/dev/null
      cd /vagrant; git init; git add .; git commit --message "commit message"

      # improve installation speed by using cache
      export LIBRARIAN_PUPPET_TMP=/vagrant/code/puppet/.tmp

      # inject settings into installation script to allow proper testing
      CONFIGURATION="
      base::source: /vagrant
      letsencrypt::staging: true
      sites::dh_keysize: 512
      base::dns::localhost_redirects: [faalkaart.test,www.faalkaart.test,admin.faalkaart.test]
      "

      GIT_SOURCE=/vagrant WEBSECMAP_CONFIGURATION="$CONFIGURATION" /vagrant/install.sh
      SHELL

    config.vm.provision "shell", inline: <<-SHELL
      # wait for everthing to be online
      echo "Waiting up to 60 seconds for websecmap to be online before starting tests."
      timeout 60 /bin/sh -c 'while sleep 1; do curl -sSvk https://faalkaart.test 2>/dev/null | grep MSPAINT >/dev/null && exit 0; done'
      SHELL

    # run serverspec as a provisioner to test the previously provisioned machine
    config.vm.provision :serverspec do |spec|
      # pattern for specfiles to search
      spec.pattern = 'tests/serverspec/{base,frontend}.rb'
    end

  end

end
