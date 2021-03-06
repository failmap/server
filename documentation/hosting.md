# WebSecMap server installation and maintenance

## Introduction

One of the core principles of the WebSecMap project is automation. This is reflected in the server configuration by having almost full configuration management. Setting up a hosted production instance of WebSecMap should be trivial and not require extensive knowledge of involved components (although it will help in troubleshooting).

The following knowledge is _required_ for basic installation:

- Basic Linux experience (using terminal/shell/ssh)

The following knowledge _may_ be needed for advanced maintenance or troubleshooting:

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

## Whats in the box

When using this installation method you will end up with a fully featured WebSecMap server including:

- Full websecmap installation with:
  - Frontend map website (with https, http/2 and caching)
  - Administrative backend (secured by TLS client certificates)
  - Workers to automatically perform scanning tasks
- Hardened server (firewall, security updates, etc)
- Monitoring dashboards (Grafana, secured by TLS client certificates)
- SSH for remote access

## Requirements

To install the fully featured WebSecMap server the following is required:

- Dedicated bare-metal or virtual host with:
  - Debian based Linux (Debian 9 or Ubuntu 18.04) clean installed
  - 1-2 CPU
  - 2-8GB RAM
  - 50-100GB disks
  - internet connectivity (IPv4 and optional IPv6)
- Terminal access to the host (SSH or via VM console, etc)
- Sudo/root permissions on the host
- DNS A record pointing to the server IPv4 addresses (and optional AAAA record for IPv6). In this document we will use `example.com` as placeholder for the DNS record name you intend to use for the website. Using a subdomain is also possible, eg: `map.example.com`. (optional, highly recommended)

## Installation

**Warning**: this installation assumes to run on a **clean and dedicated** host for a WebSecMap installation! It will **modify the OS** and take over things like firewalling, Docker, SSH, etc! **Do not run** on a server with existing other software or configuration that you do not want modified!

With that said please follow these instructions to get a WebSecMap instance up and running:

1. Bring the server up and follow the basic OS (Ubuntu/Debian) installation procedure (if it is not already installed). Configure basic settings (language, keyboard, user) as seen fit and give it a hostname you like (it does not have to match the DNS A record used for the website).

1. Log in to the server via SSH or VM terminal as `root` user. Or as normal user and sudo to root `sudo su -`.

1. Run the following command to start installation:

        wget -q -O- https://gitlab.com/internet-cleanup-foundation/server/raw/master/install.sh > /install.sh; /bin/bash /install.sh


1. Grab a Club-Mate (or 2) and wait until everything completes and you are greeted by a rainbow.

1. You WebSecMap server is now ready, you can visit the frontend at it's public IP address or the domain name (if you have already configured a DNS record).

1. HTTPS is enabled by default but with a **insecure** self-signed certificate. To properly configure automatic HTTPS using Letsencrypt please use the server tool:

        sudo websecmap-server-tool

        > Configure domain name / Setup HTTPS

1. For visiting the administrative backend (https://example.com/admin/) or monitoring (https://example.com/grafana), credentials are required. You can create and manage admin user acces using the server tool:

        sudo websecmap-server-tool

        > Manage administrative users / SSH access

## Troubleshooting

If after the installation things don't work as expected please first try the following steps:

Run server provisioning and verify configuration is complete:

1. Open a terminal (eg: SSH) on the server and become root user (`sudo su -`)

2. Run provisioning step:

        sudo websecmap-server-apply-configuration

3.    This command should provide output similar to this:

        Starting server provisioning (showing Puppet catalog compiler warnings (deprecations, etc))
        Notice: Scope(Class[Base]): fqdn=faalserver.faalkaart.test, env=hosted, os=Ubuntu 18.04.2 LTS
        Notice: Compiled catalog for faalserver.faalkaart.test in environment production in 4.49 seconds
        Notice: Applied catalog in 20.51 seconds

      Any lines between `Notice: Compiled catalog for...` and `Notice: Applied catalog in...` indicate changes made to the system. If repeated apply commands still keep showing changes made this indicates a problem with provisioning. Please contact the Internet Cleanup Foundation team for further assistance (https://gitlab.com/internet-cleanup-foundation/web-security-map#get-involved).

## Upgrading

WebSecMap server configuration is split into a _base configuration_ (maintained by Internet Cleanup Foundation at https://gitlab.com/internet-cleanup-foundation/server/) and a _server configuration_ (with customizations for a specific installation).

If new features or bugfixes are developed in the _base configuration_ the server can be updated on demand using the following procedure:

1. Open a terminal (eg: SSH) on the server and become root user (`sudo su -`)

1. Run the following command to pull in new changes and apply the configuration:

        sudo websecmap-server-update

## Configuration (advanced)

An initial configuration file (the 'server configuration') is created during installation (see above) and is stored on the server on the path: `/opt/websecmap/server/configuration/settings.yaml`

Aspects of the server can be customized in this file. All available settings and documentation can be found in this configuration file.

After the configuration file has changed, the following command has to be run to apply the new configuration:

        sudo websecmap-server-apply-configuration

## Customization (advanced)

If you want customizations outside of the current possibilities of the configuration. Or want to make custom changes on the server that will not be overwritten by the configuration system (eg: custom firewall rules). Please contact the Internet Cleanup Foundation team for further assistance. Or if you know Puppet feel free to drop a merge-request in the Gitlab repository.
