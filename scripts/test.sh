#!/bin/bash

# setup test environment and run crude integration tests

exec 2>&1
set -ve -o pipefail

function failed {
  echo "$1"
  exit 1
}

### TESTS

# generate site
/var/www/faalkaart.nl/generate.sh

# ok scenario
# site should be accessible over IPv4 HTTPS
response=$(curl -sSIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

# site should be accessible over IPv6 HTTPS
response=$(curl -6 -sSIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSIk https://localhost/index.html -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSIk https://localhost/favicon.ico -H host:faalkaart.nl)
echo "$response" | grep 200 || failed "$response"

# content renders to the end
response=$(curl -sSk https://localhost -H host:faalkaart.nl)
echo "$response" | grep MSPAINT || failed "$(echo "$response"| tail)"

# HSTS enabled
response=$(curl -sSIk https://localhost -H host:faalkaart.nl)
echo "$response" | grep 'Strict-Transport-Security: max-age=31536000; includeSubdomains' || failed "$(echo "$response"| tail)"
response=$(curl -sSI http://localhost -H host:faalkaart.nl)
echo "$response" | grep 'Strict-Transport-Security: max-age=31536000; includeSubdomains' || failed "$(echo "$response"| tail)"

# no weak crypto
weak_cryptos="DHE 1024 bits
AES128-GCM-SHA256
AES256-GCM-SHA384
AES128-SHA
AES128-SHA256
AES256-SHA
AES256-SHA256
CAMELLIA128-SHA
CAMELLIA256-SHA
DES-CBC3-SHA"

ciphers=$(sslscan --no-color -p 443 127.0.0.1)
regex="\s($(echo -n "$weak_cryptos"|tr '\n' '|'))\s"
! echo "$ciphers" | egrep --color=always "$regex" || failed "$ciphers"

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

# success
set +v
echo
echo -e "\e[92mAll good!\e[39m"
echo
