# TimescaleDB + PostGIS containers for CloudNativePG

[![Bake Images](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/bake.yml/badge.svg)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/bake.yml)
[![Validate](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/validate.yml/badge.svg)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/actions/workflows/validate.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![GHCR](https://img.shields.io/badge/ghcr.io-timescaledb--postgis-2496ED?logo=docker&logoColor=white)](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/pkgs/container/timescaledb-postgis)

Operand images for [CloudNativePG](https://cloudnative-pg.io) with **TimescaleDB**, **TimescaleDB Toolkit**, **PostGIS** and **pgRouting** added to the official CloudNativePG PostgreSQL images.

The images use the same [Docker Bake](https://docs.docker.com/build/bake/) setup that CloudNativePG uses for its own operands. Each image is the upstream `ghcr.io/cloudnative-pg/postgresql` base plus one extension layer. Every published image gets an SBOM, provenance and a cosign signature.

## Highlights

- Based on the official operand image. It runs as `USER 26` with the upstream entrypoint, so it drops straight into a `Cluster`.
- One TimescaleDB, Toolkit and PostGIS version is pinned per PostgreSQL major and distribution. A rebuild does not change extension versions.
- PostgreSQL 14 to 18 on Debian **bookworm** and **trixie**, in **standard** and **system** flavours.
- Every build-affecting PR builds three representative images and checks that each extension loads at its pinned version.
- Renovate tracks the apt pins. A weekly bake rebuilds on the latest CloudNativePG base, so PostgreSQL minor and security updates come through.

## What is inside

| Extension | Source | Version pinned |
|-----------|--------|----------------|
| `timescaledb` + loader | packagecloud (`timescale/timescaledb`) | per PostgreSQL major and distro |
| `timescaledb_toolkit` | packagecloud | per PostgreSQL major and distro |
| `postgis`, `postgis_topology` | PGDG | per distro |
| `pgrouting` | PGDG | no, follows PGDG |

The CloudNativePG base already has `pgaudit`, `pgvector` and `pg_failover_slots`. The **system** flavour also has Barman Cloud for in-cluster backups.

## Image matrix

All images are published as `ghcr.io/imusmanmalik/timescaledb-postgis`.

| PostgreSQL | bookworm | trixie |
|:----------:|:--------:|:------:|
| 14 | built | not available |
| 15 | built | built |
| 16 | built | built |
| 17 | built | built |
| 18 | built | built |

Each cell is built as `standard` and `system`, for `linux/amd64` and `linux/arm64`. TimescaleDB publishes no PostgreSQL 14 packages for trixie, so that cell is excluded.

## Tags

```
<pgMajor>-<postgis>-<type>-<distro>              # rolling, e.g. 17-3.7.0-standard-trixie
<pgFull>-<postgis>-<type>-<distro>               # e.g. 17.11-3.7.0-standard-trixie
<pgFull>-<postgis>-<YYYYMMDDhhmm>-<type>-<distro> # immutable, e.g. 17.11-3.7.0-202611060000-standard-trixie
```

The TimescaleDB and Toolkit versions are in the image labels `io.timescaledb.version` and `io.timescaledb.toolkit.version`, not in the tag.

Use the immutable dated tag or a digest in production. Rolling tags move when packages change. A pinned digest also prevents ABI mismatches, where the installed library and the default extension version disagree after a silent package upgrade.

## Quickstart

Create a single-instance cluster from an image.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  instances: 1
  imageName: ghcr.io/imusmanmalik/timescaledb-postgis:17.11-3.7.0-standard-trixie
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

To pick the image by PostgreSQL major instead of a fixed `imageName`, reference a `ClusterImageCatalog` from [`image-catalogs/`](image-catalogs/). The catalogs pin each image by digest.

```yaml
spec:
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: timescaledb-postgis-standard-trixie
    major: 17
```

Check the installed extensions.

```console
$ kubectl exec -ti cluster-example-1 -- psql app -c '\dx'
        Name         | Version |   Schema   |            Description
---------------------+---------+------------+-----------------------------------
 pgrouting           | 4.0.2   | public     | pgRouting Extension
 plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
 postgis             | 3.7.0   | public     | PostGIS geometry and geography ...
 postgis_topology    | 3.7.0   | topology   | PostGIS topology spatial types ...
 timescaledb         | 2.31.0  | public     | Enables scalable inserts and ...
 timescaledb_toolkit | 1.27.0  | public     | Library of analytical hyperfunc...
```

## Building locally

The local bake file is layered on top of the CloudNativePG source bake file, the same way CI does it.

```bash
# CI checks the CNPG source bake file out at ./source
curl -sSL https://raw.githubusercontent.com/cloudnative-pg/postgres-containers/main/docker-bake.hcl \
  -o source/docker-bake.hcl

# List every resolved target
docker buildx bake -f source/docker-bake.hcl -f docker-bake.hcl --print postgis

# Build one cell for the host arch and load it
docker buildx bake -f source/docker-bake.hcl -f docker-bake.hcl \
  postgis-3-17-standard-trixie \
  --set '*.platform=linux/arm64' --set '*.output=type=docker' \
  --provenance=false --sbom=false --load
```

`test/smoke.sh` boots an image, creates every extension and runs TimescaleDB, Toolkit, PostGIS and pgRouting queries. Set the `EXPECTED_*` variables to also assert exact versions.

```bash
EXPECTED_TIMESCALEDB=2.31.0 EXPECTED_TOOLKIT=1.27.0 EXPECTED_POSTGIS=3.7.0 \
  test/smoke.sh ghcr.io/imusmanmalik/timescaledb-postgis:17.11-3.7.0-standard-trixie
```

`validate.yml` runs the same smoke test on every PR that changes the build. `e2e.yml` runs the checks weekly against a live CloudNativePG cluster on kind.

## How it stays up to date

- Renovate (`renovate.json`) bumps the TimescaleDB and Toolkit pins from packagecloud, the PostGIS pin from PGDG, and the GitHub Actions.
- Each pin bump opens a PR that runs the smoke tests and a full bake of all 18 images.
- The weekly bake rebuilds on the current CloudNativePG base images, publishes them, and refreshes the image catalogs.

## Credits

Built on [CloudNativePG](https://cloudnative-pg.io) and the build setup of its [postgres-containers](https://github.com/cloudnative-pg/postgres-containers) and [postgis-containers](https://github.com/cloudnative-pg/postgis-containers) repositories. TimescaleDB is a product of Timescale, Inc. PostGIS is a project of the OSGeo Foundation.

## License

Available under the [Apache License 2.0](LICENSE).
