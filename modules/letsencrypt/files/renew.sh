#!/bin/sh

# update expired certificates
/etc/letsencrypt.sh/letsencrypt.sh -c --config /etc/letsencrypt.sh/config.sh 2>&1 | \
  tee "/etc/letsencrypt.sh/logs/renew-$(date +%s).log"

# make sure nginx picks them up
/usr/sbin/service nginx reload
