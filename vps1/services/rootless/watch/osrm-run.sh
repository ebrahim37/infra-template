#!/bin/sh
# Runs one osrm-routed per profile (foot :5001, bicycle :5002, car :5003) on the helper's
# active map area and restarts them whenever the helper switches or rebuilds the area.
set -u
area() { stat -L -c %i /mapcache/active/area.json 2>/dev/null || echo none; }
pids=""
# PID 1 gets no default signal handling: stop cleanly on podman/systemd stop.
trap 'kill $pids 2>/dev/null; exit 0' TERM INT

while :; do
	id=$(area)
	if [ "$id" = none ]; then
		sleep 15 &
		wait $!
		continue
	fi
	echo "routing on map area $(readlink /mapcache/active)"
	pids=""
	for p in foot:5001 bicycle:5002 car:5003; do
		osrm-routed --algorithm mld --port "${p#*:}" "/mapcache/active/osrm/${p%%:*}/region.osrm" &
		pids="$pids $!"
	done
	alive=1
	while [ "$(area)" = "$id" ] && [ "$alive" = 1 ]; do
		sleep 10 &
		wait $!
		for pid in $pids; do kill -0 "$pid" 2>/dev/null || alive=0; done
	done
	kill $pids 2>/dev/null
	wait
done
