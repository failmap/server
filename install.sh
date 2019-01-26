#!/bin/bash

# foolproof installation script for failmap

set -e

git_source=${GIT_SOURCE:-https://gitlab.com/failmap/server.git}
git_branch=${GIT_BRANCH:-master}

n="\\e[0m"
b="\\e[1m"
r="\\e[31m"
y="\\e[33m"

echo -e "${b}Welcome to Failmap installation. We will perform a few checks and ask some questions after which installation will commence.${n}"
echo
echo 'For help please visit: https://gitlab.com/failmap/server/blob/master/documentation/hosting.md'
echo
echo -e "${y}Warning: this installation script assumes to be run on a fresh installed OS and _will_ make changes to this server's OS. Press [ctrl-c] at any time to abort.${n}"

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

if ! grep -E 'Debian GNU/Linux [89]|Ubuntu 18.04' /etc/os-release >/dev/null;then
  echo "Error: this OS/release is not support!"
  cat /etc/os-release
  exit 1
fi

if test -d /opt/failmap/;then
  set -v
  # cleaning up previous attempt
  cd /
  rm -rf /.bootstrap_* /opt/failmap/
fi
set -v

# installing dependencies
apt-get update -qq >/dev/null
apt-get install -yqq git curl dnsutils >/dev/null

# getting the source
git clone --quiet --branch "$git_branch" "$git_source" /opt/failmap/server/

set +v;echo
export domain=""
while true; do
    echo -e "${b}What will be the domain name that will be served? (for example: basisbeveiliging.nl): ${n}"
    read -r domain
    echo;
    if [[ ! $domain =~ ^[a-z0-9\._-]+\.[a-z]+$ ]];then
        echo -e "${r}Error: '$domain' is not a valid domain name.\\n${n}"
        continue
    fi

    ip=$(dig +short "$domain")
    echo "Domain name '$domain' resolves to '$ip'."

    if /sbin/ip addr | grep -E "inet $ip/" >/dev/null;then
        echo "The domain name seems properly configured, continuing installation."
        break
    fi

    echo "${y}Warning: the domain name '$domain' does not resolve to an IP configured for this server.${n}"
    echo
    echo "You can continue installation and setup the domain name at a later point or retry with a different domain name."
    echo
    read -p "Do you want to continue installation with this domain name (y/n)? " -r
    if [[ $REPLY =~ ^[Yy]$ ]];then
        break
    fi
    echo
done
echo "apps::failmap::hostname: $domain" >> /opt/failmap/server/configuration/settings.yaml

export admin_email=""
while true; do
    echo -e "${b}Please enter an email address to be used for administrator notifications: ${n}"
    read -r admin_email
    echo;
    if [[ ! $admin_email =~ ^.+@.+\..+$ ]];then
        echo -e "${r}Error: '$admin_email' is not a valid email address.\\n${n}"
        continue
    fi
    break
done
echo "letsencrypt::email: $admin_email" >> /opt/failmap/server/configuration/settings.yaml

echo
echo "Saving settings in '/opt/failmap/server/configuration/settings.yaml':"
cat /opt/failmap/server/configuration/settings.yaml
echo
echo -e "${b}No more questions. Will now start installation.${n}"
echo
sleep 3

set -v

# installing configuration management dependencies
/opt/failmap/server/scripts/bootstrap.sh

# bringing the system in the desired state
/opt/failmap/server/scripts/apply.sh

cat /etc/motd