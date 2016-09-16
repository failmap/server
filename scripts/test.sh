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
response=$(curl -sSIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSIk https://localhost/index.html -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSIk https://localhost/favicon.ico -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSk https://localhost -H host:faalkaart.nl)
echo "$response" | grep MSPAINT || failed "$(echo "$response"| tail)"

# HSTS enabled
response=$(curl -sSIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 'Strict-Transport-Security: max-age=31536000; includeSubdomains' || failed "$(echo "$response"| tail)"
response=$(curl -sSI http://localhost -H host:faalkaart.nl)
echo "$response" | grep 'Strict-Transport-Security: max-age=31536000; includeSubdomains' || failed "$(echo "$response"| tail)"

# no weak crypto
weak_cryptos="DHE 1024 bits"

ciphers=$(sslscan -p 443 localhost)
! echo "$ciphers" | egrep "$(echo "$weak_cryptos"|tr '\n' '|')" || failed "$ciphers"

## test domains and redirections

# http -> https
response=$(curl -sSI http://localhost -H host:faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep 'Location: https://faalkaart.nl' || failed "$response"

# www -> no-www
response=$(curl -sSIk https://localhost -H host:www.faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep 'Location: https://faalkaart.nl' || failed "$response"

## access denied
response=$(curl -sSk https://localhost/index.php -H host:faalkaart.nl)
echo "$response" | grep 403 || failed "$response"
