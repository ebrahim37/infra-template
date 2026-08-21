#!/bin/sh
set -eu

domain_dir=/var/lib/snappymail/_data_/_default_/domains
mkdir -p "$domain_dir"
cp -f /managed-domains/* "$domain_dir"/

exec /entrypoint.sh
