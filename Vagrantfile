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

  # ensure virtualbox shared folders are used
  # debian box does not have vbguest extensions by default
  # and will default to rsync instead, which is broken and a less seamless experience
  # error: "mount: unknown filesystem type 'vboxsf'"
  # fix: `vagrant plugin install vagrant-vbguest`
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # provision using puppet
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    echo "export FACTER_env=vagrant" > /etc/profile.d/facter-env.sh
    # use tmp directory outside of vagrant root for performance and host conflict prevention
    echo "export LIBRARIAN_PUPPET_TMP=/tmp" > /etc/profile.d/use-fast-tmpdir.sh

    # install dependencies for Puppet, don't use Vagrant Puppet, we want to test bootstrapping
    /vagrant/scripts/bootstrap.sh

    # reload profile after installing puppet to pick up PATH change
    source /etc/profile

    # pull in puppet modules if required
    make -C /vagrant code/puppet/Puppetfile.lock

    # apply latests configuration
    /vagrant/scripts/apply.sh
  SHELL

  unless Vagrant.has_plugin?("vagrant-serverspec")
    raise 'vagrant-serverspec is not installed, see REAMDE.md'
  end

  # run serverspec as a provisioner to test the previously provisioned machine
  config.vm.provision :serverspec do |spec|
    # pattern for specfiles to search
    spec.pattern = 'tests/serverspec/*.rb'
  end
end
