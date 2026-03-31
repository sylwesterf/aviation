----------------------------------------------------
-- STEPS:
-- 0. create aviation database
-- 1. create schemas
-- 2. create pg metadata views
-- 3. load the shape file for time zone boundaries
----------------------------------------------------

-- 0. create aviation database and user
--CREATE USER aviation CREATEUSER PASSWORD 'password';
--ALTER USER aviation CREATEUSER;
CREATE DATABASE aviation OWNER aviation;

-- 1. create schemas
CREATE SCHEMA IF NOT EXISTS air_oai_facts;
CREATE SCHEMA IF NOT EXISTS air_oai_dims;
CREATE SCHEMA IF NOT EXISTS airlines_pg;
CREATE SCHEMA IF NOT EXISTS cal_gen;
CREATE SCHEMA IF NOT EXISTS calendar_pg;
CREATE SCHEMA IF NOT EXISTS geography;

comment on schema air_oai_dims is 'Dimension data tables and associated foreign tables for processing OAI dimension data.';
comment on schema air_oai_facts is 'Fact data and associated foreign tables and materialized views for processing OAI fact data.';
comment on schema airlines_pg is 'Views that simplify the presentation of schemata like air_ for analysis tools, such as Strategy.';
comment on schema cal_gen is 'Gregorian calendar generation views to be able to adjust data time frame in calendar schema.';
comment on schema calendar_pg is 'Gregorian calendar data as well as time transformation for ROLAP analysis.';
comment on schema geography is 'geo-political dimension and spatial data in support of aviation analysis.';

-- verify default role
select default_iam_role();
-- test the copy data command
create table test (id int, descr varchar(10));
COPY test
FROM 's3://src-aviation/test/test_file_1.csv'
IGNOREHEADER 1 
FORMAT CSV
IAM_ROLE default;
select * from test;
drop table test;

-- 2. create pg metadata views
-- database_schema_descriptions_v
CREATE OR REPLACE VIEW database_schema_descriptions_v 
AS  
SELECT n.oid as schema_oid
     , n.nspname AS schema_name
     , sum(sum_object_size_mb)::numeric(12,4) as sum_object_size_mb
     , sum(sum_total_size_mb - sum_object_size_mb)::numeric(12,4) as sum_index_size_mb
     , sum(sum_total_size_mb)::numeric(12,4) as sum_total_size_mb
     , d.description as schema_descr
FROM pg_namespace 			n
LEFT JOIN pg_description 	d ON n.oid = d.objoid
LEFT JOIN (
	SELECT relnamespace
	     , sum((pg_relation_size(oid)::float / (1000)^2))::numeric(12,4) as sum_object_size_mb
	     , sum((pg_total_relation_size(oid)::float / (1000)^2))::numeric(12,4) as sum_total_size_mb
	FROM pg_class GROUP BY relnamespace
	) 						c ON n.oid = c.relnamespace
WHERE n.nspname not in ('pg_catalog','information_schema','pg_toast')
GROUP BY n.oid, n.nspname, d.description
ORDER BY n.nspname;

-- database_objects_v
CREATE OR REPLACE VIEW database_objects_v 
AS  
SELECT current_database() AS database_name
     , n.nspname AS schema_name
     , c.relname AS object_name
     , c.relkind
     , CASE WHEN (c.relkind = 'r'::char(1)) THEN 'table'
            WHEN (c.relkind = 'v'::char(1)) THEN 'view'
            WHEN (c.relkind = 'f'::char(1)) THEN 'file'
            WHEN (c.relkind = 'i'::char(1)) THEN 'index'
            WHEN (c.relkind = 'm'::char(1)) THEN 'mview'
            ELSE '__' END::varchar(10) AS object_type
     , (pg_relation_size(c.oid)::float / (1000)^2)::numeric(12,4) AS object_size_mb
     , ((pg_total_relation_size(c.oid)::float / (1000)^2) - (pg_relation_size(c.oid)::float / (1000)^2))::numeric(12,4) as index_size_mb
     , (pg_total_relation_size(c.oid)::float / (1000)^2)::numeric(12,4) AS total_size_mb
     , d.description AS object_descr
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
LEFT JOIN (
	SELECT pg_description.objoid, pg_description.classoid, pg_description.objsubid, pg_description.description
	FROM  pg_description WHERE pg_description.objsubid = 0
	) d ON c.oid = d.objoid
LEFT JOIN (
	SELECT pg_attribute.attrelid, max(pg_attribute.attnum) AS column_count
	FROM pg_attribute
	GROUP BY pg_attribute.attrelid
	) a ON c.oid = a.attrelid
WHERE n.nspname not in ('pg_catalog','information_schema','pg_toast')
and c.relkind = 'r'
ORDER BY 3,7 desc
                                                                                                                                    
-- 3. load the shape file for time zone boundaries

/*
In order to process the Flight Performance data, we need a valid time zone name for each airport.
The dimension table from OAI does not contain this data, so we have to load the time zone boundaries
, and then update the airport history dimension: 
*/

-- Shape file for time zone boundaries was located here:
-- https://github.com/evansiroky/timezone-boundary-builder/releases/download/2023b/timezones-with-oceans.shapefile.zip
-- This is after the shape file was loaded via shp2pgsql command line tool:
-- shp2pgsql -I -s 4326 combined-shapefile-with-oceans.shp | psql -p 5432 -d aviation 

--select * from public."combined-shapefile-with-oceans" limit 10;
--alter table public."combined-shapefile-with-oceans" rename to timezone_boundaries;
