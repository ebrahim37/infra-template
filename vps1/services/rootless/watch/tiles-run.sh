#!/bin/sh
# Serves the helper's active map area (/mapcache/active/tiles.mbtiles) with tileserver-gl and
# restarts it whenever the helper switches to another area or rebuilds this one.
set -u
area() { stat -L -c %i /mapcache/active/area.json 2>/dev/null || echo none; }

export DISPLAY=:99
rm -f /tmp/.X99-lock
Xvfb "$DISPLAY" -nolisten unix >/dev/null 2>&1 &
xvfb=$!
pid=""
# PID 1 gets no default signal handling: stop cleanly on podman/systemd stop.
trap 'kill $pid $xvfb 2>/dev/null; exit 0' TERM INT

while :; do
	id=$(area)
	if [ "$id" = none ]; then
		sleep 15 &
		wait $!
		continue
	fi
	echo "serving map area $(readlink /mapcache/active)"
	node /usr/src/app/ --file /mapcache/active/tiles.mbtiles --port 8080 &
	pid=$!
	while [ "$(area)" = "$id" ] && kill -0 "$pid" 2>/dev/null; do
		sleep 10 &
		wait $!
	done
	kill "$pid" 2>/dev/null
	wait "$pid" 2>/dev/null
done
