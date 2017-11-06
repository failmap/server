This document is the primary information source on installation, maintenance and operations on a Hosted installation of the Failmap project.

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

# Installation
To install a full production Failmap stack the following is required:

- 'Server' Dedicated bare-metal or virtual host running Debian Jessie (8.0)
- SSH access to this host
- Sudo permissions on the host
- (recommended) DNS hostname/domain
- 'Workstation' (laptop/desktop running macOS/Linux) from which to apply configuration to Server

This project uses Puppet configuration management in a masterless configuration. This allows OS and applications on the Server to be shaped in the correct configuration for this project.

Git clone this repository onto the workstation.

.... librarian-puppet dependency, apply scripts, etc, todo

# Architecture
A Failmap production application consist of multiple isolated components working together to form one instance.

## Abstract components
Failmap main components:

**Frontend**
The Frontend is the public facing HTTP website of Failmap. It runs as a restricted/read-only instance with caching enabled. It's purpose is to serve as many visitor requests as efficiently as possible.

It is implemented as a restricted instance of the Admin Django App. uWSGI instance running in a Docker container with read-only Database access. In front of which the Webserver provides TLS termination and caching.

**Admin**
The Admin is a HTTP website with restricted access. It runs an read/write instance and no caching. It's purpose is to provide the administrative portal and near real-time view of the data.

It is implemented as a full instance of the Admin Django App. uWSGI instance running in a Docker container with full access to all Services (Database, Broker). In front is the Webserver providing TLS termination, client certificate validation and anti-caching.

**Worker**
The Worker is a asynchronous task executor. It picks up tasks for the Broker queue and accesses the Database for information query and result storing. All work (except for rendering HTTP responses) is handled by the Worker.

It is implemented as a Django Celery Worker running in a Docker container with full access to Database and Broker.

Multiple instances of the Worker may be running simultaniously.

**Scheduler**
The Scheduler ensures periodic tasks are scheduled at configured times. These tasks are then picked up by the Worker instance(s).

It is implemented as a Django Celery Beat running in a Docker container with full access to Database and Broker.


Supporting components/services:

**Webserver**
The Webserver provides the HTTP interface to the World-Wide-Web.

It sports Nginx providing TLS termination, client certificate authentication and on-disk (stale) caching.

**Database**
The Database provides persistant storage of all stateful data.

It is implemented as a host level MySQL instance.

**Broker**
The Broker provides a message bus for asynchronous task execution and distribution.

A redis instance bound to each specific instance (production, staging, etc) running inside a Docker container.

# Operations
This project uses containers (Docker) for management/isolation of most of its components. By maintaining state outside of these components reliability and managability is greatly improved.

Required administrative operations can be performed using utility commands. All these commands require sudo/root.

Updating to the latest release of Failmap:

    sudo failmap-deploy

Rolling back to version prior to deploy:

    sudo failmap-rollback

Clearing cache:

    sudo failmap-frontend-clear-cache

.... TODO
