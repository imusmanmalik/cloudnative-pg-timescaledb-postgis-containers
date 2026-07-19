\set ON_ERROR_STOP on

-- Optional exact-version expectations. Passed by the caller via psql -v (empty = skip),
-- so the same script works across every matrix cell while CI can assert the pinned build.
-- These are the real version gate for the ABI-mismatch class from issues #54/#56: they
-- confirm the installed extension version equals the apt pin, not just that it loaded.
\if :{?expected_timescaledb}
\else
  \set expected_timescaledb ''
\endif
\if :{?expected_toolkit}
\else
  \set expected_toolkit ''
\endif
\if :{?expected_postgis}
\else
  \set expected_postgis ''
\endif

CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION timescaledb;
CREATE EXTENSION timescaledb_toolkit;
CREATE EXTENSION pgrouting;

-- psql does not interpolate :'var' inside dollar-quoted blocks, so the expectation is
-- compared in plain SQL: on mismatch a descriptive string is cast to int, which fails
-- the cast (message included) and, under ON_ERROR_STOP, aborts the run.
SELECT CASE
  WHEN :'expected_timescaledb' <> '' AND extversion <> :'expected_timescaledb'
  THEN ('timescaledb version ' || extversion || ', expected ' || :'expected_timescaledb')::int
  ELSE 0 END AS timescaledb_version_ok
FROM pg_extension WHERE extname = 'timescaledb';

SELECT CASE
  WHEN :'expected_toolkit' <> '' AND extversion <> :'expected_toolkit'
  THEN ('toolkit version ' || extversion || ', expected ' || :'expected_toolkit')::int
  ELSE 0 END AS toolkit_version_ok
FROM pg_extension WHERE extname = 'timescaledb_toolkit';

SELECT CASE
  WHEN :'expected_postgis' <> '' AND position(:'expected_postgis' in postgis_lib_version()) = 0
  THEN ('postgis lib ' || postgis_lib_version() || ', expected ' || :'expected_postgis')::int
  ELSE 0 END AS postgis_version_ok;

-- TimescaleDB functional: hypertable + insert
CREATE TABLE metrics(ts timestamptz NOT NULL, value double precision);
SELECT create_hypertable('metrics', by_range('ts'));
INSERT INTO metrics SELECT now() - (g || ' min')::interval, g FROM generate_series(1, 10) g;
SELECT count(*) AS hypertable_rows FROM metrics;

-- Toolkit functional: build a percentile sketch and query it
SELECT approx_percentile(0.5, percentile_agg(value))::numeric(10, 2) AS toolkit_median FROM metrics;

-- PostGIS functional: geometry construction + distance
SELECT ST_AsText(ST_MakePoint(1, 2)) AS point;
SELECT round(ST_Distance(ST_MakePoint(0, 0), ST_MakePoint(3, 4))::numeric, 1) AS distance;

-- pgRouting functional: shortest path on a trivial graph
CREATE TABLE edges(id bigint, source bigint, target bigint, cost double precision, reverse_cost double precision);
INSERT INTO edges VALUES (1, 1, 2, 1, 1), (2, 2, 3, 1, 1), (3, 1, 3, 5, 5);
SELECT count(*) AS route_hops
FROM pgr_dijkstra('SELECT id, source, target, cost, reverse_cost FROM edges', 1, 3);

-- Report installed extension versions
SELECT extname, extversion FROM pg_extension ORDER BY extname;
