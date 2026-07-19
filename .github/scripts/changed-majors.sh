#!/usr/bin/env bash
set -Eeuo pipefail

base="${1:-}"
head="${2:-HEAD}"

if [ -z "$base" ]; then
	for version in TimescaleDB-PostGIS/[0-9]*; do
		[ -d "$version" ] || continue
		basename "$version"
	done
	exit 0
fi

changed_files=$(git diff --name-only "$base...$head")

{
	printf '%s\n' "$changed_files" |
		sed -n 's#^TimescaleDB-PostGIS/\([0-9][0-9]*\)/.*#\1#p'

	if printf '%s\n' "$changed_files" | grep -Eq '^TimescaleDB-PostGIS/timescaledb-pins\.json$'; then
		old_pins=$(mktemp)
		new_pins=$(mktemp)
		trap 'rm -f "$old_pins" "$new_pins"' EXIT

		if git show "$base:TimescaleDB-PostGIS/timescaledb-pins.json" >"$old_pins" 2>/dev/null; then
			cp TimescaleDB-PostGIS/timescaledb-pins.json "$new_pins"
			jq -n -r --slurpfile old "$old_pins" --slurpfile new "$new_pins" '
				(($old[0] // {}) + ($new[0] // {}) | keys[]) as $version
				| select(($old[0][$version] // null) != ($new[0][$version] // null))
				| $version
			'
		else
			jq -r 'keys[]' TimescaleDB-PostGIS/timescaledb-pins.json
		fi
	fi

	if printf '%s\n' "$changed_files" | grep -Eq '^TimescaleDB-PostGIS/(Dockerfile\.template|update\.sh|sync-timescaledb-pins\.sh)$'; then
		for version in TimescaleDB-PostGIS/[0-9]*; do
			[ -d "$version" ] || continue
			basename "$version"
		done
	fi
} | sort -Vu
