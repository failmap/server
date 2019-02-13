# Remote workers (scanners)

It is possible to enable connections from remote workers (scanners) to allow scan tasks to be distributed to these workers for higher throughput and concurrency. To enable this set the configuration paramater `apps::websecmap::broker::enable_remote` to `true`.

Remote worker connections are secured by TLS and require a valid client certificate for authentication. Currently the (letsencrypt) server certificate from the frontend (faalkaart.nl) is reused for TLS and the same CA is used for validating remote workers as for Admin and Monitoring.

Remote workers should always run in trusted environments. As workers can be configured to receive any task even the ones they are not qualified for.

Requirements:

- Running Docker daemon (see: https://docs.docker.com/install/)
- PKCS12 client certificate (a .p12 file that is also used for Admin authentication)

Use the following command to run a remote worker for a WebSecMap instance:

    docker run --rm -ti --name websecmap-worker -u nobody:nogroup \
      -e WORKER_ROLE=scanner_ipv4_only \
      -e BROKER=redis://faalkaart.nl:1337/0 \
      -v <PATH_TO_CLIENT_PKCS12>:/client.p12 \
      websecmap/websecmap:latest \
      celery worker --loglevel info --concurrency=10

`WORKER_ROLE` determines the kind of tasks this worker will pick up, for reference: https://gitlab.com/websecmap/websecmap/blob/master/websecmap/celery/worker.py

`BROKER` is the URL to the Redis message broker to connect to.

`-v <PATH_TO_CLIENT_PKCS12>:/client_key.p12` replace `<PATH_TO_CLIENT_KEY>` with the actual path to the required client certificat to allow the worker to connect to the broker. You will be prompted for a passphrase if required.

Only one worker should be run per host (ie: IP address) due to concurrency limits by external parties (eg: Qualys). Per worker instance this will be accounted for with rate limiting. To increase concurrency for other tasks increate the concurrency value

Loglevel can be increased (debug) or decreased (warning, error, critical, fatal).

To run in the background pass the `-d` argument after `run`. This is not yet compatible with PKCS12 passphrase prompt.
