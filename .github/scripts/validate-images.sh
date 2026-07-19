#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")/../.."

base="${1:-}"
mapfile -t majors < <(.github/scripts/changed-majors.sh "$base" HEAD)

if [ "${#majors[@]}" -eq 0 ]; then
	echo "No PostgreSQL image changes detected."
	exit 0
fi

for major in "${majors[@]}"; do
	image="local/timescaledb-postgis:${major}"
	echo "Building PostgreSQL ${major} image"
	docker build --platform linux/amd64 \
		-t "$image" \
		-f "TimescaleDB-PostGIS/${major}/Dockerfile" \
		"TimescaleDB-PostGIS/${major}"

	echo "Smoke testing PostgreSQL ${major} image"
	.github/scripts/smoke-image.sh "$major" "$image"
done
