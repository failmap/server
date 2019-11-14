#!/bin/bash

# foolproof installation script for websecmap

set -e

git_source=${GIT_SOURCE:-https://gitlab.com/internet-cleanup-foundation/server/}
git_branch=${GIT_BRANCH:-master}
configuration=${WEBSECMAP_CONFIGURATION}

n="\\e[39m"
b="\\e[1m"
y="\\e[33m"

echo -e "${b}Welcome to WebSecMap installation.${n}"
echo
echo 'For help please visit: https://gitlab.com/internet-cleanup-foundation/server/blob/master/documentation/hosting.md'
echo
echo -e "${y}Warning: this installation script assumes to be run on a fresh installed OS and _will_ make changes to this server's OS. Press [ctrl-c] at any time to abort.${n}"

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

if ! grep -E 'Debian GNU/Linux 9|Ubuntu 18.04' /etc/os-release >/dev/null;then
  . /etc/os-release
  echo "Error: the OS/release '$PRETTY_NAME' is not supported!"
  exit 1
fi

if test -d /opt/websecmap/;then
  set -v
  # cleaning up previous attempt
  cd /
  rm -rf /.bootstrap_* /opt/websecmap/
fi

# prevent daily apt update from interfering with install
# https://unix.stackexchange.com/a/315517
systemctl stop apt-daily.service
systemctl kill --kill-who=all apt-daily.service 2>/dev/null || true

# wait until `apt-get updated` has been killed
timeout 10 /bin/bash -c "while ! (systemctl status apt-daily.service | grep -F -q dead); do sleep 1; done"

# installing dependencies
apt-get update -qq >/dev/null
apt-get install -yqq git >/dev/null

# getting the source
git clone --quiet --branch "$git_branch" "$git_source" /opt/websecmap/server/

# installing configuration management dependencies
/opt/websecmap/server/scripts/bootstrap.sh

if ! test -z "$configuration"; then
  echo "$configuration" >> /opt/websecmap/server/configuration/settings.yaml
else
  # set empty root password to allow login via console
  passwd -d root
  # configure web interface user
  password=$(pwgen -B1s 32)
  cat > /opt/websecmap/server/configuration/settings.yaml <<EOF
accounts::users:
  wsm-user:
    sudo: true
    webpassword: $password
EOF
fi

# bringing the system in the desired state
if /opt/websecmap/server/scripts/apply.sh; then
  cat /etc/banner
  echo
  echo -e "${b}Confgratulations... Your Web Security Map installation is now ready.${n}"
  echo
  echo "You can visit your Web Security Map at: https://$(/opt/puppetlabs/bin/facter networking.ip)"
  echo
  echo "The Administrative section is available at: https://$(/opt/puppetlabs/bin/facter networking.ip)/admin"
  if ! test -z "$password";then
    echo
    echo "You may login with the user 'wsm-user' and password '$password'"
  fi
  echo
  echo "Because the domain name and HTTPS is not setup yet you will get a security warning that you need to click trough."
  echo
  echo "For further setup (domain name, https, user accounts, SSH, etc) please run the server tool:"
  echo -e "  ${b}sudo websecmap-server-tool${n}"
else
  echo
  echo -e "${b}We apologize for the inconvenience.${n}"
  echo
  echo "But something went wrong during the installation."
  echo
  echo "You can retry the last step by running: "
  echo -e "  ${b}/opt/websecmap/server/scripts/apply.sh${n}"
  echo
  echo "If things still fail please consider opening an issue at:"
  echo "  https://gitlab.com/internet-cleanup-foundation/server/issues/new"
fi
if ! test -z "$password"; then
  echo
  echo "Root login to this server is disabled for SSH. You can log in via console as user root with no password."
fi
echo
