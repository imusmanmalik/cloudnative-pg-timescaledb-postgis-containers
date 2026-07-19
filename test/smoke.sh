#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: smoke.sh <image-ref>}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm --entrypoint bash \
  -v "$DIR/smoke.sql:/smoke.sql:ro" \
  "$IMAGE" -c '
    set -eux
    export PGDATA=/tmp/pgdata
    # initdb / pg_ctl are on PATH in CNPG images; fall back to the versioned bindir if not.
    command -v initdb >/dev/null || export PATH="/usr/lib/postgresql/17/bin:$PATH"
    initdb -D "$PGDATA" -U postgres
    pg_ctl -D "$PGDATA" -o "-k /tmp -c shared_preload_libraries=timescaledb" -w start
    psql -U postgres -h /tmp -v ON_ERROR_STOP=1 -f /smoke.sql
  '
