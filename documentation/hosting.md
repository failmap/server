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

- 'Server' Dedicated bare-metal or virtual host running *Debian Jessie (8.0)*
- SSH access to the host
- Sudo/root permissions on the host
- (recommended) DNS hostname/domain

Login to the server as `root` or as normal user and sudo to root `sudo su -`.

Run the following command:

    wget -q -o- https://gitlab.com/failmap/server/raw/master/install.sh | /bin/bash

Wait until everything completes and the notice `Applied catalog in xxx seconds` appears.