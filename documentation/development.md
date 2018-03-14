# Quickstart/local testing/development

For local testing/development a Vagrant setup is provided with this repsitory. This allows to run a local instance of the entire Failmap environment in a virtual machine.

## Requirements

The following tools are required to run the virtual machine:

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://www.vagrantup.com/downloads.html)
- vagrant-vbguest (`vagrant plugin install vagrant-vbguest`)
- vagrant-landrush (`vagrant plugin install landrush`)
- vagrant-serverspec(`vagrant plugin install vagrant-serverspec`)

## Instructions

Run the following command and wait for the provisioning to complete.

    vagrant up

At the end of provisioning a test suite is ran to ensure the machine is in a desired state. See `serverspec/` for more information regarding testing.

After this the virtual machine is accessible by running:

    vagrant ssh

And can be stopped/removed using these commands:

    vagrant halt
    vagrant destroy

To access the website point your browser to:

    http://faalserver.faalkaart.test

