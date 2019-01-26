#!/bin/bash -e

n="\\e[0m"
b="\\e[1m"
r="\\e[31m"
y="\\e[33m"

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

    if /sbin/ip addr | grep -E "inet $ip/";then
        echo "The domain name seems properly configured, continuing installation."
        break
    fi

    echo "${y}Warning: the domain name '$domain' does not resolve to an IP configured for this server.${n}"
    echo
    echo "You can continue installation and setup the domain name at a later point or retry with a different domain name."
    echo
    read -p "Do you want to continue installation with this domain name (y/n)?" -n1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]];then
        break
    fi
    echo
done
echo

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
echo

# echo "What will be the "

# prompt "What is your name!" http://www.montypython.net/scripts/HG-bridgescene.php
