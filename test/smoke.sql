\set ON_ERROR_STOP on

CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION timescaledb;
CREATE EXTENSION timescaledb_toolkit;
CREATE EXTENSION pgrouting;

-- TimescaleDB functional: hypertable + insert
CREATE TABLE metrics(ts timestamptz NOT NULL, value double precision);
SELECT create_hypertable('metrics', by_range('ts'));
INSERT INTO metrics VALUES (now(), 42.0);
SELECT count(*) AS hypertable_rows FROM metrics;

-- PostGIS functional
SELECT ST_AsText(ST_MakePoint(1, 2)) AS point;

-- pgRouting present
SELECT count(*) AS pgr_functions FROM pg_proc WHERE proname = 'pgr_dijkstra';

-- Report installed extension versions
SELECT extname, extversion FROM pg_extension ORDER BY extname;
