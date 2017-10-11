#!/bin/bash

# setup test environment and run crude integration tests

domain=${1:-faalkaart.nl}

if ping6 -c1 "$domain"; then
  v6=true
else
  echo "Notice: Skipping IPv6 tests due to IPv6 unavailability!"
  v6=false
fi

function failed {
  echo "$1"
  exit 1
}

exec 2>&1
set -ve -o pipefail

### TESTS

# ok scenario
# site should be accessible over IPv4 HTTPS
response=$(curl -sSIk "https://$domain")
echo "$response" | grep 200 || failed "$response"

if $v6;then
  # site should be accessible over IPv6 HTTPS
  response=$(curl -6 -sSIk "https://$domain")
  echo "$response" | grep 200 || failed "$response"
fi

response=$(curl -sSIk "https://$domain/index.html")
echo "$response" | grep 200 || failed "$response"

response=$(curl -sSIk "https://$domain/favicon.ico")
echo "$response" | grep 200 || failed "$response"

# content renders to the end
response=$(curl -sSk "https://$domain")
echo "$response" | grep MSPAINT || failed "$(echo "$response"| tail)"

# HSTS enabled
response=$(curl -sSIk "https://$domain")
echo "$response" | grep 'Strict-Transport-Security: max-age=31536000; includeSubdomains' || failed "$(echo "$response"| tail)"
response=$(curl -sSI http://faalkaart.nl)
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

ciphers=$(sslscan --no-color -p 443 faalkaart.nl)
regex="\s($(echo -n "$weak_cryptos"|tr '\n' '|'))\s"
! echo "$ciphers" | egrep --color=always "$regex" || failed "$ciphers"

## test domains and redirections

# http -> https
response=$(curl -sSI http://faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep "Location: https://$domain" || failed "$response"

# www -> no-www
response=$(curl -sSIk https://www.faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep "Location: https://$domain" || failed "$response"

## access denied
response=$(curl -sSk "https://$domain/index.php")
echo "$response" | grep 403 || failed "$response"

## Admin frontend

# should be alive
response=$(curl -sSIk "https://admin.$domain")
echo "$response" | grep 200 || failed "$response"

# success
set +v
echo
echo -e "\e[92mAll good!\e[39m"
echo
