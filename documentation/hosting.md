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

- Dedicated bare-metal or virtual host with internet connectivity running either:
  - Debian 8
  - Debian 9
  - Ubuntu 18.04
- Terminal access to the host (SSH or via VM console, etc)
- Sudo/root permissions on the host
- Hostnames pointing to the server IPv4 and IPv6 addresses (replace example.com with your primary domain):

  - example.com
  - admin.example.com
  - grafana.example.com
  - failserver.example.com (optional)

**Warning**: this installation assumes to run on a clean and dedicated host for a Failmap installation! It will modify the OS and take over things like firewalling, Docker, SSH, etc. Do not run on a server with existing other software as the actions performed cannot be undone easily/automatically.

1. Bring the server up, configure basic settings (language, keyboard, user) as seen fit and give it a hostname like: `failserver.example.com` (this is used to match configuration, see next step). Using the frontend hostname (`example.com`) is not advised.

1. Create a server hostname configuration in `configuration/per-hostname/` with the hostname previously chosen. (see other files in the `configuration/` directory for documentations/examples). 

1. Make sure this file is commited to the repository and pushed to Gitlab `master` or create your own fork of this repository and adjust the URL in step 5 accordingly!

1. Login to the server as `root` or as normal user and sudo to root `sudo su -`.

1. Run the following command:

        wget -q -O- https://gitlab.com/failmap/server/raw/master/install.sh | /bin/bash

1.  Grab a Mate (or 2) and wait until everything completes and the notice `Applied catalog in xxx seconds` appears.


# Upgrading

1. Login on the machine you want to upgrade.

1. If not available, download the server sources neede for the upgrade:
1. Make the failmap directory: `mkdir /opt/failmap/` and download the sources `git clone https://gitlab.com/failmap/server/`

1. Go to /opt/failmap/server `cd /opt/failmap/server`

1. Download the new server sources: `git pull origin`

1. Apply the update by running apply.sh: `./scripts/apply.sh`



