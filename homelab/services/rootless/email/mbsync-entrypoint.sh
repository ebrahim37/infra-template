#!/bin/sh
set -u

trap 'exit 0' INT TERM

for mailbox in "gmail main" "gmail qa" icloud; do
	/bin/mkdir -p "/mail/$mailbox/cur" "/mail/$mailbox/new" "/mail/$mailbox/tmp"
done

while :; do
	/usr/bin/mbsync --config /etc/mbsyncrc --all ||
		echo "mbsync failed; retrying in three minutes" >&2

	/bin/sleep 180 &
	wait $! || exit 0
done
