#!/bin/sh
set -u

trap 'exit 0' INT TERM

while :; do
	/usr/bin/mbsync --config /etc/mbsyncrc --all ||
		echo "mbsync failed; retrying in three minutes" >&2

	/bin/sleep 180 &
	wait $! || exit 0
done

