#!/bin/bash

# friendly UI to manage Failmap server

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

self="$(readlink -f "$0")"

set -e

echo "Gathering information"

public_ip=$(/opt/puppetlabs/bin/facter networking.ip)
hostname=$(hostname)
domainname=$(/opt/puppetlabs/bin/puppet lookup --hiera_config /opt/failmap/server/code/puppet/hiera.yaml --render-as s apps::failmap::hostname 2>/dev/null)
if [ -z "$domainname" ];then
  domainname="(not configured)"
fi
server_version=$(git --git-dir /opt/failmap/server/.git rev-list --all --count)
server_commit=$(git --git-dir /opt/failmap/server/.git rev-parse --short HEAD)

app_version=$(/usr/local/bin/failmap shell -c 'import failmap; print(failmap.__version__)' 2>/dev/null)

function server_information {
  server_information=$(cat <<EOF
Public IP: $public_ip
Server hostname: $hostname
Website domain name: $domainname

Server configuration version: $server_version ($server_commit)
Failmap application version: $app_version
EOF
)

  whiptail --title "Server Information" --msgbox "$server_information" 15 60
}

function mainmenu {
  sleep 0.1
  choice=$(whiptail --notags --title "Server administration tool" --menu "" 12 78 6 \
    "info" "Show server information (again)." \
    "domainname" "Add/change frontend domain name." \
    "update_server" "Update server configuration." \
    "update_app" "Update the Failmap application." \
    "users" "Add/remove administrative users." \
    "exit" "Exit the tool." 3>&1 1>&2 2>&3)
    if test -z "$choice" ;then
      choice="exit"
    fi
    echo "$choice"
}

server_information

while true;do
  choice=$(mainmenu)
  test "info" == "$choice" && exec "$self"
  test "update_server" == "$choice" && (/usr/local/bin/failmap-server-apply-configuration;sleep 5)
  test "update_app" == "$choice" && (/usr/local/bin/failmap-deploy;sleep 5)
  test "users" == "$choice" && /usr/games/sl -alF
  test "exit" == "$choice" && exit 0
done