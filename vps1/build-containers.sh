#!/bin/sh
set -eu

script_path=$(realpath "$0")
repo_dir=$(dirname "$script_path")
dest="$repo_dir/services-dist"
copier_config="$repo_dir/services/copier.yml"

{
	echo "_envops:"
	echo "  undefined: jinja2.StrictUndefined"
} > "$copier_config"

podman run --rm --interactive --log-driver=none \
	--security-opt label=disable \
	--volume "$repo_dir:/src:ro" \
	--volume "$repo_dir/services:/services" \
	--workdir /src \
	docker.io/library/python:3.13-alpine \
	sh -eu -c '
		python -m pip install --quiet --root-user-action=ignore copier
		copier copy --quiet --data-file answers.yml services /services/.render
	'

rm -rf "$dest" "$copier_config"
mv "$repo_dir/services/.render" "$dest"

if command -v systemctl >/dev/null 2>&1; then
	systemctl --user daemon-reload || true
	sudo -n systemctl daemon-reload || true
fi
