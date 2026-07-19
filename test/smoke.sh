#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: smoke.sh <image-ref>}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional exact-version expectations, forwarded into the container and asserted by
# smoke.sql. Unset = the script only checks that extensions load and work.
docker run --rm --entrypoint bash \
  -e "EXPECTED_TIMESCALEDB=${EXPECTED_TIMESCALEDB:-}" \
  -e "EXPECTED_TOOLKIT=${EXPECTED_TOOLKIT:-}" \
  -e "EXPECTED_POSTGIS=${EXPECTED_POSTGIS:-}" \
  -v "$DIR/smoke.sql:/smoke.sql:ro" \
  "$IMAGE" -c '
    set -eux
    export PGDATA=/tmp/pgdata
    # initdb / pg_ctl are on PATH in CNPG images; fall back to whatever versioned bindir
    # the image actually ships (do not assume a specific PG major).
    if ! command -v initdb >/dev/null; then
      for d in /usr/lib/postgresql/*/bin; do PATH="$d:$PATH"; done
      export PATH
    fi
    initdb -D "$PGDATA" -U postgres
    pg_ctl -D "$PGDATA" -o "-k /tmp -c shared_preload_libraries=timescaledb" -w start
    psql -U postgres -h /tmp -v ON_ERROR_STOP=1 \
      -v expected_timescaledb="${EXPECTED_TIMESCALEDB}" \
      -v expected_toolkit="${EXPECTED_TOOLKIT}" \
      -v expected_postgis="${EXPECTED_POSTGIS}" \
      -f /smoke.sql
  '
