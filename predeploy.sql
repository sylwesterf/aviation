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
    schema_oid,
    schema_name,
    sum(estimated_size)::NUMERIC(12,4) AS sum_total_size_mb
FROM duckdb_tables() 
where database_name = 'aviation'
group by 1,2;

-- database_objects_v
CREATE OR REPLACE VIEW database_objects_v AS  
SELECT 
    database_name ,
    schema_name,
    table_name AS object_name,
    CASE WHEN internal THEN 'i' ELSE 'r' END AS relkind,
    CASE WHEN temporary THEN 'temp_table' ELSE 'table' END::VARCHAR(10) AS object_type,
    sum(estimated_size)::NUMERIC(12,4) AS sum_total_size_mb 
FROM duckdb_tables()
where database_name = 'aviation'
group by 1,2,3,4,5
ORDER BY object_name;

-- 4. native shape file for time zone boundaries

/*
In order to process the Flight Performance data, we need a valid time zone name for each airport.
The dimension table from OAI does not contain this data, so we have to update it using the time zone boundaries. 
DuckDB's Spatial extension reads shapefiles directly using the GDAL driver.

# download shape file for time zone boundaries
wget https://github.com/evansiroky/timezone-boundary-builder/releases/download/2023b/timezones-with-oceans.shapefile.zip 
unzip timezones-with-oceans.shapefile.zip

# upload to S3 bucket
*/

CREATE OR REPLACE TABLE timezone_boundaries AS 
SELECT * FROM ST_Read('s3://src-aviation/DIMS/CSV/combined-shapefile-with-oceans.shp');

select * replace (st_astext(geom) as geom)
from timezone_boundaries 
limit 10;
