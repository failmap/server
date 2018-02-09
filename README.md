This repository contains server provisioning for the Failmap project (https://faalkaart.nl). This Readme focusses on local development and testing of the Failmap project. For information about running Failmap in production refer to: `HOSTED.md`.

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

## Remote workers (scanners)

It is possible to enable connections from remote workers (scanners) to allow scan tasks to be distributed to these workers for higher throughput and concurrency. To enable this set the configuration paramater `apps::failmap::broker::enable_remote` to true.

Remote worker connections are secured by TLS and require a valid client certificate for authentication. Currently the (letsencrypt) server certificate from the frontend (faalkaart.nl) is reused for TLS and the same CA is used for validating remote workers as for Admin and Monitoring.

Remote workers should always run in trusted environments. As workers can be configured to receive any task even the ones they are not qualified for.

Requirements:

- Running Docker daemon (see: https://docs.docker.com/install/)
- PKCS12 client certificate (a .p12 file that is also used for Admin authentication)

Use the following command to run a remote worker for a Failmap instance:

    docker run --rm -ti --name failmap-worker -u nobody:nogroup \
      -e WORKER_ROLE=scanner_ipv4_only \
      -e BROKER=redis://faalkaart.nl:1337/0 \
      -v <PATH_TO_CLIENT_PKCS12>:/client.p12 \
      registry.gitlab.com/failmap/failmap:latest \
      celery worker --loglevel info --concurrency=10

`WORKER_ROLE` determines the kind of tasks this worker will pick up, for reference: https://gitlab.com/failmap/failmap/blob/master/failmap/celery/worker.py

`BROKER` is the URL to the Redis message broker to connect to.

`-v <PATH_TO_CLIENT_PKCS12>:/client_key.p12` replace `<PATH_TO_CLIENT_KEY>` with the actual path to the required client certificat to allow the worker to connect to the broker. You will be prompted for a passphrase if required.

Only one worker should be run per host (ie: IP address) due to concurrency limits by external parties (eg: Qualys). Per worker instance this will be accounted for with rate limiting. To increase concurrency for other tasks increate the concurrency value

Loglevel can be increased (debug) or decreased (warning, error, critical, fatal).

To run in the background pass the `-d` argument after `run`. This is not yet compatible with PKCS12 passphrase prompt.
