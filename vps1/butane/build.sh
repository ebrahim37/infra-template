#!/bin/sh
set -eu

script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
repo_dir=$(dirname "$script_dir")
render_dir="$repo_dir/butane/.render"
copier_config="$repo_dir/butane/copier.yml"

{
	echo "_envops:"
	echo "  undefined: jinja2.StrictUndefined"
} > "$copier_config"

podman run --rm --interactive --log-driver=none \
	--security-opt label=disable \
	--volume "$repo_dir:/src:ro" \
	--volume "$repo_dir/butane:/butane" \
	--workdir /src \
	docker.io/library/python:3.13-alpine \
	sh -eu -c '
		python -m pip install --quiet --root-user-action=ignore copier
		copier copy --quiet --data-file answers.yml butane /butane/.render
	'

podman run --rm --interactive --log-driver=none \
	--security-opt label=disable \
	--volume "$render_dir:/render:ro" \
	quay.io/coreos/butane:release \
	--strict --pretty /render/config.bu > "$repo_dir/butane/config.ign"

rm -rf "$render_dir" "$copier_config"
