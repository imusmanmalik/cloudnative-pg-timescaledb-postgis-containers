ARG BASE=ghcr.io/cloudnative-pg/postgresql:17.10-standard-trixie
FROM $BASE

ARG PG_MAJOR=17
ARG POSTGIS_MAJOR=3
ARG POSTGIS_VERSION
ARG TIMESCALEDB_VERSION
ARG TIMESCALEDB_TOOLKIT_VERSION

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget gnupg; \
    install -d /usr/share/keyrings; \
    wget -qO- https://packagecloud.io/timescale/timescaledb/gpgkey \
      | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg; \
    codename="$(. /etc/os-release; echo "$VERSION_CODENAME")"; \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ ${codename} main" \
      > /etc/apt/sources.list.d/timescaledb.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      "postgresql-${PG_MAJOR}-postgis-${POSTGIS_MAJOR}=${POSTGIS_VERSION}" \
      "postgresql-${PG_MAJOR}-postgis-${POSTGIS_MAJOR}-scripts=${POSTGIS_VERSION}" \
      "postgresql-${PG_MAJOR}-pgrouting" \
      "timescaledb-2-loader-postgresql-${PG_MAJOR}=${TIMESCALEDB_VERSION}" \
      "timescaledb-2-postgresql-${PG_MAJOR}=${TIMESCALEDB_VERSION}" \
      "timescaledb-toolkit-postgresql-${PG_MAJOR}=${TIMESCALEDB_TOOLKIT_VERSION}"; \
    apt-get purge -y --auto-remove wget gnupg; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

USER 26
