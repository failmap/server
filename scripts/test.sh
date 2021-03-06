#!/bin/bash

# setup test environment and run crude integration tests

curl_http2='docker run -ti getourneau/alpine-curl-http2 curl'

domain=${1:-faalkaart.nl}

if ping6 -c1 "$domain" >/dev/null; then
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

# give docker apps a little room to come online after an initial provision
for app in admin.$domain demo.$domain; do
  # try every second for 10 second to get a good response from app
  timeout 10 /bin/sh -c "while ! curl -sSIk https://\"$app\" &>/dev/null | grep 200;do sleep 1;done" || true
done

set -ve -o pipefail

# install dependencies
sudo /vagrant/scripts/install_sslscan.sh

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

response=$(curl -sSIk "https://$domain/static/favicon.ico")
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
regex="\\s($(echo -n "$weak_cryptos"|tr '\n' '|'))\\s"
! echo "$ciphers" | grep -E --color=always "$regex" || failed "$ciphers"

## test domains and redirections

# http -> https
response=$(curl -sSI http://faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep "Location: https://$domain" || failed "$response"

# www -> no-www
response=$(curl -sSIk https://www.faalkaart.nl)
echo "$response" | grep 301 || failed "$response"
echo "$response" | grep "Location: https://$domain" || failed "$response"

# ## Admin frontend
#
# # should be alive
# response=$(curl -sSIk "https://admin.$domain")
# echo "$response" | grep 200 || failed "$response"
#
# # caching should be disabled
# response=$(curl -sSIk "https://admin.$domain")
# echo "$response" | grep 'Cache-Control: no-cache' || failed "$response"

# cache should be enabled

# skip, currently no endpoint which does not specify cache explicitly
# # app does not set cache for the index, webserver default should be used
# response=$(curl -sSIk "https://$domain")
# echo "$response" | grep 'Cache-Control: max-age=600' || failed "$response"

# stats have explicit cache which is different from the webserver 10 minute default
# implicitly tests database migrations as it will return 500 if they are not applied
response=$(curl -sSIk "https://$domain/data/terrible_urls/0")
echo "$response" | grep 'Cache-Control: max-age=86400' || failed "$response"

# all responses should be compressed
# proxied html
response=$(curl --compressed -sSIk "https://$domain/")
echo "$response" | grep 'Content-Encoding: gzip' || failed "$response"
# proxied JSON
response=$(curl --compressed -sSIk "https://$domain/data/stats/0")
echo "$response" | grep 'Content-Encoding: gzip' || failed "$response"
# proxied static files
response=$(curl --compressed -sSIk "https://$domain/static/images/internet_cleanup_foundation_logo.png")
echo "$response" | grep 'Content-Encoding: gzip' || failed "$response"

# http/2 support
response=$($curl_http2 --http2 -sSIk "https://demo.$domain/")
echo "$response" | grep 'HTTP/2 200' || failed "$response"

# webserver should serve stale responses if backend is down
# indirectly this tests server caching as well
curl -sSIk "https://$domain"
sudo systemctl stop docker-websecmap-frontend.service
response=$(curl -sSIk "https://$domain")
echo "$response" | grep 200 || failed "$response"
sudo systemctl start docker-websecmap-frontend.service

# success
set +v
echo
echo -e "\\e[92mAll good!\\e[39m"
echo
