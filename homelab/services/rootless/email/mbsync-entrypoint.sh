#!/bin/sh
set -u

for mailbox in "gmail main" "gmail qa" icloud; do
	/bin/mkdir -p "/mail/$mailbox/INBOX/cur" "/mail/$mailbox/INBOX/new" "/mail/$mailbox/INBOX/tmp"
done

sync_all() {
	/usr/bin/mbsync --config /etc/mbsyncrc --all ||
		echo "fallback mbsync failed; retrying later" >&2
}

fallback_sync() {
	while :; do
		/bin/sleep 180
		sync_all
	done
}

shutdown() {
	status=$1
	trap - INT TERM
	/bin/kill "$idle_pid" "$fallback_pid" 2>/dev/null || true
	wait "$idle_pid" 2>/dev/null || true
	wait "$fallback_pid" 2>/dev/null || true
	exit "$status"
}

# Populate every configured mailbox before switching to event-driven updates.
sync_all

fallback_sync &
fallback_pid=$!

/usr/bin/goimapnotify -conf /etc/goimapnotify.yaml &
idle_pid=$!

trap 'shutdown 0' INT TERM

wait "$idle_pid"
status=$?
shutdown "$status"
