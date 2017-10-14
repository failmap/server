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

# give docker apps a little room to come online after an initial provision
for app in admin.$domain demo.$domain; do
  # try every second for 10 second to get a good response from app
  timeout 10 /bin/sh -c "while ! curl -sSIk https://\"$app\" | grep 200;do sleep 1;done"
done

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

# caching should be disabled
response=$(curl -sSIk "https://admin.$domain")
echo "$response" | grep 'Cache-Control: no-cache' || failed "$response"

## Demo

# should be alive
response=$(curl -sSIk "https://demo.$domain")
echo "$response" | grep 200 || failed "$response"

# cache should be enabled
# app does not set cache for the index, webserver default should be used
response=$(curl -sSIk "https://demo.$domain")
echo "$response" | grep 'Cache-Control: max-age=600' || failed "$response"

# static file cache is determined by webserver
# stats have a 1 day cache which is different from the webserver 10 minute default
# implicitly tests database migrations as it will return 500 if they are not applied
response=$(curl -sSIk "https://demo.$domain/data/stats/0")
echo "$response" | grep 'Cache-Control: max-age=86400' || failed "$response"

# success
set +v
echo
echo -e "\e[92mAll good!\e[39m"
echo
