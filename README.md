This repository contains server provisioning for the Failmap project. This Readme focusses on local development and testing of the Failmap project. For information about running Failmap in production refer to: `HOSTED.md`.

# Quickstart/local testing/development

For local testing/development a Vagrant setup is provided with this repsitory. This allows to run a local instance of the entire Failmap environment in a virtual machine.

## Requirements

The following tools are required to run the virtual machine:

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://www.vagrantup.com/downloads.html)
- vagrant-vbguest (`vagrant plugin install vagrant-vbguest`)
- vagrant-landrush (`vagrant plugin install landrush`)

## Instructions

Run the following command and wait for the provisioning to have completed.

    vagrant up
    vagrant ssh -- /vagrant/scripts/test.sh

The test should complete with the words `All good!` which indicated the post-provision test suite has verified the installation is correct.

After this the virtual machine is accessible by running:

    vagrant ssh

And can be stopped/removed using these commands:

    vagrant halt
    vagrant destroy

To access the website point your browser to:

    http://faalserver.faalkaart.test
