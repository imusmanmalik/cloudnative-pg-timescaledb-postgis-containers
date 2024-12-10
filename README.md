# cloudnative-pg-timescaledb-postgis-containers

Operand images for CloudNativePG containing PostgreSQL with TimescaleDB and PostGIS

Immutable Application Containers for all available PostgreSQL versions (12 to 17) + TimescaleDB + PostGIS to be used as operands 
with the [CloudNativePG operator](https://cloudnative-pg.io) for Kubernetes.

These images are built on top of the [PostGIS image](https://hub.docker.com/r/postgis/postgis)
(Debian version), by adding the following software:

- TimescaleDB
- Barman Cloud
- PGAudit

Barman Cloud is distributed by EnterpriseDB under the
[GNU GPL 3 License](https://github.com/EnterpriseDB/barman/blob/master/LICENSE).

PGAudit is distributed under the
[PostgreSQL License](https://github.com/pgaudit/pgaudit/blob/master/LICENSE).

Images are available via the
[GitHub Container Registry](https://github.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/pkgs/container/timescaledb-postgis).

## How to use them

The following example shows how you can easily create a new PostgreSQL 14
cluster with TimescaleDB 2.10 and PostGIS 3.3 in it. All you have to do is set the `imageName`
accordingly. Please look at the registry for a list of available images
and select the one you need.

Create a YAML manifest. For example, you can put the YAML below into a file
named `timescaledb-postgis.yaml` (any name is fine). (Please refer to
[CloudNativePG](https://cloudnative-pg.io/docs) for details on the API):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-example
spec:
  instances: 1
  imageName: ghcr.io/imusmanmalik/timescaledb-postgis:14-3.3
  bootstrap:
    initdb:
      postInitTemplateSQL:
        - CREATE EXTENSION timescaledb;
        - CREATE EXTENSION postgis;
        - CREATE EXTENSION postgis_topology;
        - CREATE EXTENSION fuzzystrmatch;
        - CREATE EXTENSION postgis_tiger_geocoder;
  postgresql:
    shared_preload_libraries:
      - timescaledb
  storage:
    size: 1Gi
```

Then run `kubectl apply -f timescaledb-postgis.yaml`.

When the cluster is up, run the following command to verify the version of
PostGIS that is available in the system, by connecting to the `app` database:

```console
kubectl exec -ti cluster-example-1 -- psql app
Defaulted container "postgres" out of: postgres, bootstrap-controller (init)
psql (14.7 (Debian 14.7-1.pgdg110+1))
Type "help" for help.

app=# SELECT * FROM pg_available_extensions WHERE name ~ '^postgis' ORDER BY 1;
           name           | default_version | installed_version |                          comment

--------------------------+-----------------+-------------------+----------------------------------------------------
--------
 postgis                  | 3.3.2           | 3.3.2             | PostGIS geometry and geography spatial types and fu
nctions
 postgis-3                | 3.3.2           |                   | PostGIS geometry and geography spatial types and fu
nctions
 postgis_raster           | 3.3.2           |                   | PostGIS raster types and functions
 postgis_raster-3         | 3.3.2           |                   | PostGIS raster types and functions
 postgis_sfcgal           | 3.3.2           |                   | PostGIS SFCGAL functions
 postgis_sfcgal-3         | 3.3.2           |                   | PostGIS SFCGAL functions
 postgis_tiger_geocoder   | 3.3.2           | 3.3.2             | PostGIS tiger geocoder and reverse geocoder
 postgis_tiger_geocoder-3 | 3.3.2           |                   | PostGIS tiger geocoder and reverse geocoder
 postgis_topology         | 3.3.2           | 3.3.2             | PostGIS topology spatial types and functions
 postgis_topology-3       | 3.3.2           |                   | PostGIS topology spatial types and functions
(10 rows)

app=# SELECT * FROM pg_available_extensions WHERE name ~ '^timescaledb' ORDER BY 1;
        name         | default_version | installed_version |                                        comment

---------------------+-----------------+-------------------+---------------------------------------------------------
------------------------------
 timescaledb         | 2.10.0          | 2.10.0            | Enables scalable inserts and complex queries for time-se
ries data
 timescaledb_toolkit | 1.14.0          |                   | Library of analytical hyperfunctions, time-series pipeli
ning, and other SQL utilities
(2 rows)
```

The following command shows the extensions installed in the `app` database,
thanks to the `postInitTemplateSQL` section in the bootstrap which runs the
selected `CREATE EXTENSION` commands in the `template1` database, which is
inherited by the application database - called `app` and created by default by
CloudNativePG.

```console
app=# \dx
                                           List of installed extensions
          Name          | Version |   Schema   |                            Description
------------------------+---------+------------+-------------------------------------------------------------------
 fuzzystrmatch          | 1.1     | public     | determine similarities and distance between strings
 plpgsql                | 1.0     | pg_catalog | PL/pgSQL procedural language
 postgis                | 3.3.2   | public     | PostGIS geometry and geography spatial types and functions
 postgis_tiger_geocoder | 3.3.2   | tiger      | PostGIS tiger geocoder and reverse geocoder
 postgis_topology       | 3.3.2   | topology   | PostGIS topology spatial types and functions
 timescaledb            | 2.10.0  | public     | Enables scalable inserts and complex queries for time-series data
(6 rows)
```

You can now enjoy TimescaleDB and PostGIS!

## License and copyright

This software is available under [Apache License 2.0](LICENSE).
