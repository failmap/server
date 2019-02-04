#!/bin/bash

# friendly UI to manage Failmap server

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

self="$(readlink -f "$0")"

set -e

echo -n "Gathering information"

public_ip=$(/opt/puppetlabs/bin/facter networking.ip)
echo -n .
hostname=$(hostname -f)
echo -n .
domainname=$(/opt/puppetlabs/bin/puppet lookup --hiera_config /opt/failmap/server/code/puppet/hiera.yaml \
  --render-as s apps::failmap::hostname 2>/dev/null)
if [ -z "$domainname" ];then
  domainname="(not configured)"
fi
echo -n .
admin_email=$(/opt/puppetlabs/bin/puppet lookup --hiera_config /opt/failmap/server/code/puppet/hiera.yaml \
  --render-as s letsencrypt::email 2>/dev/null)
if [ -z "$admin_email" ];then
  admin_email="(not configured)"
fi
echo -n .

server_version=$(git --git-dir /opt/failmap/server/.git rev-list --all --count)
echo -n .
server_commit=$(git --git-dir /opt/failmap/server/.git rev-parse --short HEAD)
echo -n .

app_version=$(/usr/local/bin/failmap shell -c 'import failmap; print(failmap.__version__)' 2>/dev/null)
echo -n .
echo

function server_information {
  server_information=$(cat <<EOF
Public IP: $public_ip
Server hostname: $hostname
Website domain name: $domainname
Administrative e-mail: $admin_email

Server configuration version: $server_version ($server_commit)
Failmap application version: $app_version
EOF
)

  whiptail --title "Server Information" --msgbox "$server_information" 15 60
}

function configure_domainname {
  domainname=$1
  admin_email=$2

  cat > /opt/failmap/server/configuration/settings.d/domainname.yaml <<EOF
apps::failmap::hostname: $domainname
letsencrypt::staging: false
letsencrypt::email: $admin_email
EOF

  /usr/local/bin/failmap-server-apply-configuration
}

function domainname {
  while true; do
      text=$(cat <<EOF
What domain name should the frontend website be served under?

For proper security and HTTPS the domain name for the frontend needs to be
explicitly configured.
EOF
)
      domainname=$(whiptail --inputbox "$text" \
        10 78 "$domainname" --title "Domain Name" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ! $exitstatus = 0 ]; then
        return
      fi
      if [[ ! $domainname =~ ^[a-z0-9\._-]+\.[a-z]+$ ]];then
          echo -e "${r}Error: '$domainname' is not a valid domain name.\\n${n}"
          continue
      fi

      echo "Verifying if provided domain name '$domainname' can be used."
      ip=$(dig +short "$domainname")
      echo "Domain name '$domainname' resolves to '$ip'."
      sleep 3

      if ! /sbin/ip addr | grep -E "inet $ip/";then
        echo "Warning: the domain name '$domainname' does not resolve to an IP configured for this server."
        echo
        echo "It is possible the domain name is configured properly but DNS has not propagated yet."
        echo
        read -p "Do you want to continue configuration of this domain name (y/n)?" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]];then
            break
        fi
      fi
      break
  done
  echo "The domain name seems properly configured."

  while true; do
      admin_email=$(whiptail --inputbox "Please specify an email address that will be used for Letsencrypt (https)" \
        8 78 "$admin_email" --title "Admin Email"  3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
          break
      fi

      if [[ ! $admin_email =~ ^.+@.+$ ]];then
          echo -e "${r}Error: '$admin_email' is not a valid e-mail address.\\n${n}"
          continue
      fi
  done

  configure_domainname "$domainname" "$admin_email"
}

function mainmenu {
  sleep 0.1
  menu=(
    "info" "Show server information (again)"
    "stats" "Server diagnostics (cpu, memory, etc)"
    "logs" "Server logs (live)"
    "loghistory" "Server logs (history)"
    "" ""
    "domainname" "Add/change frontend domain name"
    "users" "Add/remove administrative users"
    "" ""
    "update_server" "Update server configuration"
    "update_app" "Update the Failmap application"
    "" ""
    "exit" "Exit the tool"
  )
  choice=$(whiptail --notags --title "Server administration tool" --menu "" \
    "$((${#menu[@]} / 2 + 6))" 78 "$((${#menu[@]} / 2))" "${menu[@]}" 3>&1 1>&2 2>&3)
  if test -z "$choice" ;then
    choice="exit"
  fi
  echo "$choice"
}

server_information

while true;do
  choice=$(mainmenu)
  if test "info" == "$choice";then server_information; fi
  if test "stats" == "$choice";then atop; fi
  if test "logs" == "$choice";then journalctl -f; fi
  if test "loghistory" == "$choice";then journalctl; fi
  if test "domainname" == "$choice";then domainname; fi
  if test "update_server" == "$choice";then /usr/local/bin/failmap-server-update;sleep 5; fi
  if test "update_app" == "$choice";then /usr/local/bin/failmap-deploy;sleep 5; fi
  if test "users" == "$choice";then /usr/games/sl -alF; fi
  if test "exit" == "$choice";then exit 0; fi
done