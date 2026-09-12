#!/bin/sh
set -eu

install -d -m 0755 /var/www/html/plugins/autologin
install -m 0644 \
    /entrypoint-tasks/post-setup/autologin.php \
    /var/www/html/plugins/autologin/autologin.php
