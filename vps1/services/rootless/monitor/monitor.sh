#!/bin/sh
set -u

state_dir=/var/lib/quadlet-monitor
interval=60
debounce=600

: "${MONITOR_HOST:?MONITOR_HOST is required}"
: "${NTFY_URL:?NTFY_URL is required}"
mkdir -p "$state_dir" || exit 1

unit_name() {
	name=$(awk '
		/^[[:space:]]*ServiceName[[:space:]]*=/ {
			sub(/^[^=]*=[[:space:]]*/, "")
			sub(/[[:space:]]*$/, "")
			print
			exit
		}
	' "$1" 2>/dev/null)
	[ -n "$name" ] || name=$(basename "$1" .container)
	printf '%s.service\n' "$name"
}

check_scope() {
	scope=$1
	dir=$2

	find "$dir" -type f -name '*.container' 2>/dev/null | sort |
	while IFS= read -r quadlet; do
		unit=$(unit_name "$quadlet")
		[ "$unit" = monitor.service ] && continue

		case $scope in
			rootful) state=$(systemctl --system is-active "$unit" 2>/dev/null || true) ;;
			rootless) state=$(systemctl --user is-active "$unit" 2>/dev/null || true) ;;
		esac
		[ -n "$state" ] || state=unknown

		incident=$state_dir/$scope--$unit
		alerted=$incident.alerted
		if [ "$state" = active ]; then
			rm -f "$incident" "$alerted"
			continue
		fi

		now=$(date +%s)
		since=
		[ ! -r "$incident" ] || IFS= read -r since < "$incident" || since=
		case $since in
			''|*[!0-9]*)
				since=$now
				printf '%s\n' "$since" > "$incident" || continue
				;;
		esac

		if [ ! -e "$alerted" ] && [ "$((now - since))" -ge "$debounce" ]; then
			title="$MONITOR_HOST: $unit $state"
			body="$unit ($scope) has been $state for at least 10 minutes."
			if curl --fail --location --silent --show-error --max-time 15 \
				-H "Title: $title" --data-binary "$body" "$NTFY_URL/monitor"; then
				: > "$alerted"
			else
				printf '%s\n' "failed to notify for $unit ($scope)" >&2
			fi
		fi
	done
}

while :; do
	check_scope rootful /quadlets/rootful
	check_scope rootless /quadlets/rootless
	sleep "$interval"
done
