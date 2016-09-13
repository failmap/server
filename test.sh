#!/bin/bash

# setup test environment and run crude integration tests

exec 2>&1
set -ve -o pipefail

function failed {
  echo "$1"
  exit 1
}

### SETUP

# start and wait for mysql
/usr/sbin/mysqld &
timeout 10 /bin/sh -c 'while ! nc localhost 3306 -w1 >/dev/null ;do sleep 1; done'

# start and wait for nginx
/usr/sbin/nginx -g 'daemon off;' &
timeout 10 /bin/sh -c 'while ! nc localhost 80 -w1 2>/dev/null >/dev/null ;do sleep 1; done'

### TESTS

# generate site
/var/www/faalkaart.nl/generate.sh

# ok scenario
response=$(curl -sIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sIk https://localhost/index.html -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sIk https://localhost/favicon.ico -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sk https://localhost -H host:faalkaart.nl)
echo "$response" | grep MSPAINT || failed "$(echo "$response"| tail)"

## test domains and redirections

# http -> https
response=$(curl -sI http://localhost -H host:faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep 'Location: https://faalkaart.nl' || failed "$response"

# www -> no-www
response=$(curl -sIk https://localhost -H host:www.faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep 'Location: https://faalkaart.nl' || failed "$response"

## access denied
response=$(curl -sk https://localhost/index.php -H host:faalkaart.nl)
echo "$response" | grep 403 || failed "$response"
