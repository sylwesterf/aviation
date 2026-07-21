----------------------------------------------------
-- STEPS:
-- 0. create aviation database
-- 1. create schemas
-- 2. load core extensions
-- 3. create pg metadata views
-- 4. load the shape file for time zone boundaries
----------------------------------------------------

-- 0. create aviation database
ATTACH 'aviation.db' AS aviation;
USE aviation;

-- 1. create schemas
CREATE SCHEMA IF NOT EXISTS air_oai_facts;
CREATE SCHEMA IF NOT EXISTS air_oai_dims;
CREATE SCHEMA IF NOT EXISTS airlines_ddb;
CREATE SCHEMA IF NOT EXISTS cal_gen;
CREATE SCHEMA IF NOT EXISTS calendar_ddb;
CREATE SCHEMA IF NOT EXISTS geography;

-- 2. load core extensions
INSTALL spatial;
LOAD spatial;
INSTALL httpfs;
LOAD httpfs;
INSTALL aws;
LOAD aws;

-- assume EC2 role credentials for S3 connectivity
CREATE OR REPLACE SECRET (
    TYPE S3, 
    PROVIDER credential_chain
);

-- test s3 connectivity
CREATE TABLE IF NOT EXISTS test (id INT, descr VARCHAR);

INSERT INTO test 
SELECT * FROM read_csv('s3://src-aviation/test/test_file_1.csv');

SELECT * FROM test;
DROP TABLE test;

-- 3. create metadata views
-- database_schema_descriptions_v
CREATE OR REPLACE VIEW database_schema_descriptions_v AS  
SELECT 
    schema_oid AS schema_oid,
    schema_name AS schema_name,
    -- DuckDB tables store data columnarly; rough approximations can be pulled from disk tracking
    0.0000::NUMERIC(12,4) AS sum_object_size_mb,
    0.0000::NUMERIC(12,4) AS sum_index_size_mb,
    0.0000::NUMERIC(12,4) AS sum_total_size_mb,
    ''::VARCHAR AS schema_descr
FROM duckdb_schemas()
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'main');

-- database_objects_v
CREATE OR REPLACE VIEW database_objects_v AS  
SELECT 
    database_name AS database_name,
    schema_name AS schema_name,
    table_name AS object_name,
    'aviation'::VARCHAR AS owner_name,
    CASE WHEN internal THEN 'i' ELSE 'r' END AS relkind,
    CASE WHEN temporary THEN 'temp_table' ELSE 'table' END::VARCHAR(10) AS object_type,
    0.0000::NUMERIC(12,4) AS object_size_mb,
    0.0000::NUMERIC(12,4) AS index_size_mb,
    0.0000::NUMERIC(12,4) AS total_size_mb,
    comment AS object_descr
FROM duckdb_tables()
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY object_name;

-- 4. native shape file for time zone boundaries

/*
In order to process the Flight Performance data, we need a valid time zone name for each airport.
The dimension table from OAI does not contain this data, so we have to update it using the time zone boundaries. 
DuckDB's Spatial extension reads shapefiles directly using the GDAL driver. This bypasses shp2pgsql entirely.
*/

CREATE TABLE timezone_boundaries AS 
SELECT * FROM ST_Read('combined-shapefile-with-oceans.shp');

SELECT * FROM timezone_boundaries LIMIT 10;