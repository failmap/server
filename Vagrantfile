# -*- mode: ruby -*-
# vi: set ft=ruby :

unless ARGV[0] == "plugin"
  required_plugins = %w( vagrant-vbguest vagrant-serverspec )
  plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
  if not plugins_to_install.empty?
    puts "Installing plugins: #{plugins_to_install.join(' ')}"
    if system "vagrant plugin install #{plugins_to_install.join(' ')}"
      exec "vagrant #{ARGV.join(' ')}"
    else
      abort "Installation of one or more plugins has failed. Aborting."
    end
  end
end

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
    # use tmp directory outside of vagrant root for performance and host conflict prevention
    echo "export LIBRARIAN_PUPPET_TMP=/tmp" > /etc/profile.d/use-fast-tmpdir.sh
    . /etc/profile.d/use-fast-tmpdir.sh

    # install dependencies for Puppet, don't use Vagrant Puppet, we want to test bootstrapping
    /vagrant/scripts/bootstrap.sh

    # apply latests configuration
    SHOW_WARNINGS=1 /vagrant/scripts/apply.sh

    # wait for everthing to be online
    timeout 30 /bin/sh -c 'while sleep 1; do curl -sSvk https://faalkaart.test 2>/dev/null | grep MSPAINT >/dev/null && exit 0; done'
    SHELL

  # run serverspec as a provisioner to test the previously provisioned machine
  config.vm.provision :serverspec do |spec|
    # pattern for specfiles to search
    spec.pattern = 'tests/serverspec/*.rb'
  end

  config.vm.post_up_message = "Tell people to visit http://faalkaart.faalserver.test"
end
