#!/bin/bash

set -e

# Docker specific setup for testsuite

# start and wait for mysql
# workaround: https://github.com/docker/for-linux/issues/72
find /var/lib/mysql -type f -exec touch {} \;
/usr/sbin/mysqld  &
timeout 30 /bin/sh -c 'while ! nc localhost 3306 -w1 >/dev/null ;do sleep 1; done'

# start and wait for nginx
/usr/sbin/nginx -g 'daemon off;' &
timeout 30 /bin/sh -c 'while ! nc localhost 80 -w1 2>/dev/null >/dev/null ;do sleep 1; done'

scripts/test.sh
