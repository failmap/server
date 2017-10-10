#!/bin/bash

# bootstrap/provision inside docker container and run testsuite

set -e

source/scripts/bootstrap.sh
source/scripts/apply.sh

# Docker specific setup for testsuite

# start and wait for mysql
# workaround: https://github.com/docker/for-linux/issues/72
find /var/lib/mysql -type f -exec touch {} \;
/usr/sbin/mysqld  &
timeout 30 /bin/sh -c 'while ! nc localhost 3306 -zw1 >/dev/null ;do sleep 1; done'

# start and wait for nginx
/usr/sbin/nginx -g 'daemon off;' &
timeout 30 /bin/sh -c 'while ! nc localhost 80 -zw1 2>/dev/null >/dev/null ;do sleep 1; done'

source/scripts/test.sh
