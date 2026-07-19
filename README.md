# TimescaleDB + PostGIS containers for CloudNativePG

[![Bake Images](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/bake.yml/badge.svg)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/bake.yml)
[![Validate](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/validate.yml/badge.svg)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/validate.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![GHCR](https://img.shields.io/badge/ghcr.io-timescaledb--postgis-2496ED?logo=docker&logoColor=white)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/pkgs/container/timescaledb-postgis)

Operand images for [CloudNativePG](https://cloudnative-pg.io) that add **TimescaleDB**,
**TimescaleDB Toolkit**, **PostGIS**, and **pgRouting** on top of the official CloudNativePG
PostgreSQL images - so you get time-series and geospatial Postgres as a first-class CNPG operand.

The images are built with the same [Docker Bake](https://docs.docker.com/build/bake/) machinery
CloudNativePG uses for its own operands. Each image is the upstream
`ghcr.io/cloudnative-pg/postgresql` base with a single extension layer added, and inherits its
SBOM, provenance, and cosign signatures for free.

## Highlights

- **Real CNPG operand** - based on the official operand image, runs as `USER 26` with the
  unchanged entrypoint. Drop it straight into a `Cluster`.
- **Pinned, reproducible extensions** - one TimescaleDB, Toolkit, and PostGIS version pinned per
  PostgreSQL major and distribution. No surprise upgrades between rebuilds.
- **PostgreSQL 14 to 18**, on Debian **bookworm** and **trixie**, in **standard** and **system**
  flavours.
- **Tested every build** - each PR builds representative images and asserts the extensions load
  and their versions match the pins (container smoke) with an optional CNPG kind end-to-end test.
- **Kept current automatically** - Renovate tracks the apt pins; a weekly bake rebuilds against
  the latest CNPG base so PostgreSQL minor and security updates flow through.

## What is inside

Added by this image:

| Extension | Source |
|-----------|--------|
| `timescaledb` + loader | packagecloud (`timescale/timescaledb`) |
| `timescaledb_toolkit` | packagecloud |
| `postgis`, `postgis_topology` | PGDG |
| `pgrouting` | PGDG |

Already provided by the CloudNativePG base: `pgaudit`, `pgvector`, `pg_failover_slots`. The
**system** flavour additionally ships Barman Cloud for in-cluster backups.

## Image matrix

Image name: `ghcr.io/imusmanmalik/timescaledb-postgis`

| PostgreSQL | bookworm | trixie |
|:----------:|:--------:|:------:|
| 14 | built | not available |
| 15 | built | built |
| 16 | built | built |
| 17 | built | built |
| 18 | built | built |

Each cell is built for both `standard` and `system`, on `linux/amd64` and `linux/arm64`.
TimescaleDB publishes no PostgreSQL 14 packages for trixie, so that one cell is intentionally
excluded.

### Tags

```
<pgMajor>-<postgis>-<type>-<distro>              # rolling, e.g. 17-3.6.4-standard-trixie
<pgFull>-<postgis>-<type>-<distro>               # e.g. 17.10-3.6.4-standard-trixie
<pgFull>-<postgis>-<YYYYMMDDhhmm>-<type>-<distro> # immutable, e.g. 17.10-3.6.4-202607190900-standard-trixie
```

The pinned TimescaleDB and Toolkit versions are recorded in image **labels**
(`io.timescaledb.version`, `io.timescaledb.toolkit.version`), not in the tag.

> **Use the immutable dated tag (or a digest) for production.** Rolling tags move when packages
> change. Pinning the digest is what makes an image reproducible - this is the class of problem
> behind ABI-mismatch reports where an installed library disagrees with the default extension
> version; the pinned pins plus the version-assertion smoke tests guard against it.

## Quickstart

Create a single-instance cluster from an image:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  instances: 1
  imageName: ghcr.io/imusmanmalik/timescaledb-postgis:17.10-3.6.4-standard-trixie
  postgresql:
    shared_preload_libraries:
      - timescaledb
  bootstrap:
    initdb:
      postInitTemplateSQL:
        - CREATE EXTENSION timescaledb;
        - CREATE EXTENSION timescaledb_toolkit;
        - CREATE EXTENSION postgis;
        - CREATE EXTENSION postgis_topology;
        - CREATE EXTENSION pgrouting;
  storage:
    size: 1Gi
```

```bash
kubectl apply -f cluster-example.yaml
```

### Using an image catalog

Instead of a hard-coded `imageName`, reference a `ClusterImageCatalog` and pick the image by
PostgreSQL major. Catalogs live in [`image-catalogs/`](image-catalogs/):

```yaml
spec:
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: timescaledb-postgis-standard-trixie
    major: 17
```

### Verify

```console
$ kubectl exec -ti cluster-example-1 -- psql app -c '\dx'
        Name         | Version |   Schema   |            Description
---------------------+---------+------------+-----------------------------------
 pgrouting           | 4.0.1   | public     | pgRouting Extension
 plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
 postgis             | 3.6.4   | public     | PostGIS geometry and geography ...
 postgis_topology    | 3.6.4   | topology   | PostGIS topology spatial types ...
 timescaledb         | 2.28.3  | public     | Enables scalable inserts and ...
 timescaledb_toolkit | 1.23.0  | public     | Library of analytical hyperfunc...
```

## Building locally

The local bake file layers on top of the CloudNativePG source bake file, exactly as CI does:

```bash
# Fetch the CNPG source bake file (mounted at ./source in CI)
curl -sSL https://raw.githubusercontent.com/cloudnative-pg/postgres-containers/main/docker-bake.hcl \
  -o source/docker-bake.hcl

# See every resolved target
docker buildx bake -f source/docker-bake.hcl -f docker-bake.hcl --print postgis

# Build a single cell for your host arch and load it
docker buildx bake -f source/docker-bake.hcl -f docker-bake.hcl \
  postgis-3-17-standard-trixie \
  --set '*.platform=linux/arm64' --set '*.output=type=docker' --set '*.attest=' --load
```

### Testing

Run the container smoke test against a built image. It boots the image, creates every extension,
runs functional TimescaleDB / PostGIS / pgRouting / Toolkit queries, and optionally asserts exact
versions:

```bash
EXPECTED_TIMESCALEDB=2.28.3 EXPECTED_TOOLKIT=1.23.0 EXPECTED_POSTGIS=3.6.4 \
  test/smoke.sh ghcr.io/imusmanmalik/timescaledb-postgis:17.10-3.6.4-standard-trixie
```

The same smoke test is the required PR gate (`validate.yml`); `e2e.yml` runs it against a live
CloudNativePG cluster on kind.

## How it stays up to date

- **Renovate** (`renovate.json`) bumps the TimescaleDB and Toolkit pins (packagecloud) and the
  PostGIS pin (PGDG) directly in `docker-bake.hcl`, plus the GitHub Actions.
- Every pin-bump PR must pass the `validate.yml` smoke tests before it can merge.
- The weekly **bake** run rebuilds against the current CloudNativePG base images and refreshes the
  image catalogs.

## Credits

Built on [CloudNativePG](https://cloudnative-pg.io) and its
[postgres-containers](https://github.com/cloudnative-pg/postgres-containers) /
[postgis-containers](https://github.com/cloudnative-pg/postgis-containers) build machinery.
TimescaleDB is a product of Timescale, Inc. PostGIS is a project of the OSGeo Foundation.

## License

Available under the [Apache License 2.0](LICENSE).
