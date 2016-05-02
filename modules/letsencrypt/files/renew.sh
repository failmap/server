#!/bin/sh

# update expired certificates
/etc/letsencrypt.sh/letsencrypt.sh -c 2>&1 | \
  tee "/etc/letsencrypt.sh/logs/renew-$(date +%s).log"

# make sure nginx picks them up
service nginx reload
