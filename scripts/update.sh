#!/bin/bash

# pull in upstream changes and apply new configuration

set -e

cd /opt/failmap/server
git pull
/opt/failmap/server/scripts/apply.sh