ARG BASE=ghcr.io/cloudnative-pg/postgresql:17.10-standard-trixie
FROM $BASE

ARG PG_MAJOR=17
ARG POSTGIS_MAJOR=3
ARG POSTGIS_VERSION
ARG PGROUTING_VERSION
ARG ADDRESS_STANDARDIZER_VERSION
ARG TIGER_GEOCODER_VERSION
ARG TIMESCALEDB_VERSION
ARG TIMESCALEDB_TOOLKIT_VERSION

USER root

# Since PostGIS 3.7 Debian ships address_standardizer and the tiger geocoder as separate
# packages. The tiger geocoder is only packaged for PostgreSQL 16 and later.
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
      "postgresql-${PG_MAJOR}-address-standardizer=${ADDRESS_STANDARDIZER_VERSION}" \
      "postgresql-${PG_MAJOR}-pgrouting=${PGROUTING_VERSION}" \
      "postgresql-${PG_MAJOR}-pgrouting-scripts=${PGROUTING_VERSION}" \
      "timescaledb-2-loader-postgresql-${PG_MAJOR}=${TIMESCALEDB_VERSION}" \
      "timescaledb-2-postgresql-${PG_MAJOR}=${TIMESCALEDB_VERSION}" \
      "timescaledb-toolkit-postgresql-${PG_MAJOR}=${TIMESCALEDB_TOOLKIT_VERSION}"; \
    if [ "$PG_MAJOR" -ge 16 ]; then \
      apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}-postgis-tiger-geocoder=${TIGER_GEOCODER_VERSION}"; \
    fi; \
    apt-get purge -y --auto-remove wget gnupg; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

# Fail the build when a packaging split drops an extension. address_standardizer follows
# the PostGIS minor version; the tiger geocoder has its own version.
RUN set -eu; \
    ext="/usr/share/postgresql/${PG_MAJOR}/extension"; \
    postgis="${POSTGIS_VERSION%%+*}"; \
    short="${postgis%.*}"; \
    check() { grep -q "^default_version = '$2'" "$ext/$1.control" \
      || { echo "ERROR: $1 is not at version $2" >&2; exit 1; }; }; \
    check postgis "$postgis"; \
    check address_standardizer "$short"; \
    check address_standardizer_data_us "$short"; \
    if [ "$PG_MAJOR" -ge 16 ]; then \
      check postgis_tiger_geocoder "${TIGER_GEOCODER_VERSION%%-*}"; \
    fi

USER 26
