#!/usr/bin/env bash
set -Eeuo pipefail

major="$1"
image="$2"
container="ts-postgis-smoke-${major}-$$"

cleanup() {
	docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --platform linux/amd64 --rm -d \
	--name "$container" \
	-e POSTGRES_PASSWORD=postgres \
	"$image" >/dev/null

for _ in $(seq 1 60); do
	if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

docker exec "$container" test -f "/usr/lib/postgresql/${major}/lib/pg_failover_slots.so"
docker exec "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
	-c "ALTER SYSTEM SET shared_preload_libraries TO 'timescaledb','pgaudit';"

docker restart "$container" >/dev/null

for _ in $(seq 1 60); do
	if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

docker exec "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS pgaudit;
CREATE EXTENSION IF NOT EXISTS pgrouting;
SELECT extname, extversion
FROM pg_extension
WHERE extname IN (
	'timescaledb',
	'timescaledb_toolkit',
	'postgis',
	'postgis_topology',
	'pgaudit',
	'pgrouting'
)
ORDER BY extname;
"

docker stop "$container" >/dev/null
trap - EXIT
