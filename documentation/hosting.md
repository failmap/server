# Introduction
One of the core principles of the Failmap project is automation. This is reflected in the server configuration by having almost full configuration management and reproducable builds. Setting up a hosted production instance of Failmap should be trivial and not require extensive knowledge of involved components (although it will help in troubleshooting).

The following technologies may be encountered when working on Failmap:

- Linux (Debian)
- Puppet
- Docker
- Nginx
- MySQL
- Python
- Django
- Redis
- Celery
- Git
- Consul

Additionally knowledge of the following related technologies is advised:

- Virtualization/Hosting
- DNS
- Networking

This project uses Puppet configuration management in a masterless configuration. This allows OS and applications on the host to be shaped in the correct configuration for this project.

# Installation
To install a full production Failmap stack the following is required:

- 'Server' Dedicated bare-metal or virtual host running Debian Jessie (8.0)
- SSH access to the host
- Sudo permissions on the host
- (recommended) DNS hostname/domain
- 'Workstation' (laptop/desktop running macOS/Linux) from which to apply configuration to the host.

These instructions have been tested on macOS High Siera. All required dependencies are already available in the default macOS installation and otherwise will be installed automatically in an local environment. Developer command line tools (`git`, `make`) might need to be installed using: `xcode-select --install`.

Git clone this repository onto the workstation:

    git clone https://gitlab.com/failmap/server
    cd server

Or download and extract using https://gitlab.com/failmap/server/-/archive/master/server-master.zip).

Run bootstrap to install required dependencies on host (where example.com is assumed the target host and a default Debian Jessie (8.0) installation is assumed). If you have not set the proper username in your `~/.ssh/config` you can provide it here using `host=user@example.com`.

    make bootstrap host=example.com

Go to `configuration/` and create at least a `settings.yaml` or `per-host/example.com.yaml` file (see `.dist` examples) and adjust configuration to desired settings.

If you want to configure the bare minimum run the following using a real email address:

    echo "letsencrypt::email: YOURREAL@EMAILADDRESS" >> configuration/settings.yaml

Run the following command to provision the host according to code and configuration:

    make apply host=example.com

This command may be run as often as is needed, and should be run at least once after a change to code or configuration. Instead of applying changes directly the following command allows to see changes that would be applied:

    make plan host=example.com
