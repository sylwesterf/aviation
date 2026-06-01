----------------------------------------------------
-- Vanilla PostgreSQL (PostGIS + pg_analytics for S3/local CSV).
-- Prerequisite: shared_preload_libraries = 'pg_analytics' in postgresql.conf, then restart.
-- STEPS:
-- 0. create aviation database
-- 1. create schemas
-- 2. create pg extensions 
-- 3. create pg metadata views
-- 4. define auxiliary stored procedures
--  4.1. create partitioning stored procedure
-- 5. load the shape file for time zone boundaries
----------------------------------------------------

-- 0. create aviation database and user
--CREATE user aviation WITH PASSWORD 'password';
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

-- 2. create extensions
CREATE EXTENSION IF NOT EXISTS postgis; -- geometry columns in air_oai_dims.airport_history
CREATE EXTENSION IF NOT EXISTS pg_analytics; -- DuckDB-backed reads from S3, HTTPS, or local files

-- pg_analytics exposes one general-purpose FDW (name is historical). It reads Parquet, CSV,
-- JSON, and other formats; DuckDB infers the format from the path in OPTIONS (files '...').
-- See: https://pgxn.org/dist/pg_analytics/0.3.5/README.html (File/Table Formats: CSV, Parquet, ...)
DROP SERVER IF EXISTS pg_analytics_s3 CASCADE;
DROP FOREIGN DATA WRAPPER IF EXISTS s3_wrapper;
CREATE FOREIGN DATA WRAPPER s3_wrapper
    HANDLER s3_fdw_handler
    VALIDATOR s3_fdw_validator;
CREATE SERVER pg_analytics_s3 FOREIGN DATA WRAPPER s3_wrapper;

-- test pg_analytics connectivity (S3 URI; requires AWS credentials in the environment)
create table test (id int, descr varchar(10));
DROP FOREIGN TABLE IF EXISTS test_csv_ft;
CREATE FOREIGN TABLE test_csv_ft ()
SERVER pg_analytics_s3
OPTIONS (files 's3://src-aviation/test/test_file_1.csv');
INSERT INTO test SELECT * FROM test_csv_ft;
DROP FOREIGN TABLE test_csv_ft;
select * from test;
drop table test;

-- 3. create pg metadata views
-- database_schema_descriptions_v
CREATE OR REPLACE VIEW database_schema_descriptions_v 
AS  
SELECT n.oid as schema_oid
     , max(n.nspname) AS schema_name
     , sum(sum_object_size_mb)::numeric(12,4) as sum_object_size_mb
     , sum(sum_total_size_mb - sum_object_size_mb)::numeric(12,4) as sum_index_size_mb
     , sum(sum_total_size_mb)::numeric(12,4) as sum_total_size_mb
     , max(d.description) as schema_descr
FROM pg_namespace 			n
LEFT JOIN pg_description 	d ON n.oid = d.objoid
LEFT JOIN (
	SELECT relnamespace
	     , sum((pg_relation_size(oid)::float / (1000)^2))::numeric(12,4) as sum_object_size_mb
	     , sum((pg_total_relation_size(oid)::float / (1000)^2))::numeric(12,4) as sum_total_size_mb
	FROM pg_class GROUP BY relnamespace
	) 						c ON n.oid = c.relnamespace
WHERE n.nspname not in ('pg_catalog','information_schema','pg_toast')
GROUP BY n.oid
ORDER BY n.nspname;

-- database_objects_v
CREATE OR REPLACE VIEW database_objects_v 
AS  
SELECT current_database() AS database_name
     , n.nspname AS schema_name
     , c.relname AS object_name
     , u.rolname AS owner_name
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
JOIN pg_roles u ON c.relowner = u.oid
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
ORDER BY 3,7 desc;

-- 4. define stored procedures -
-- 4.1. create partitioning stored procedure for airfare survey data
CREATE OR REPLACE PROCEDURE create_quarter_partitions(
    IN p_parent_table text,   -- e.g. 'air_oai_facts.airfare_survey_itinerary'
    IN p_source_table text    -- e.g. 'air_oai_facts.airfare_survey_ticket_fdw'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_year          int;
    v_max_year          int;
    v_last_year_max_qtr int;

    year_val    int;
    quarter_val int;
    start_date  date;
    end_date    date;
    table_name  text;
    sql_stmt    text;
BEGIN

    -- Determine minimum and maximum year from the year_quarter_start_date    
        EXECUTE format(
        'SELECT 
             min(EXTRACT(YEAR FROM year_quarter_start_date))::int,
                    max(EXTRACT(YEAR FROM year_quarter_start_date))::int
             FROM %s',
            p_source_table
        )
        INTO v_min_year, v_max_year;

    IF v_min_year IS NULL OR v_max_year IS NULL THEN
        RAISE EXCEPTION
            'No data found in % or column year_quarter_start_date is NULL',
            p_source_table;
    END IF;

    -- Determine the maximum quarter (1–4) for the maximum year.
        EXECUTE format(
            'SELECT max(EXTRACT(QUARTER FROM year_quarter_start_date))
             FROM %s
             WHERE EXTRACT(YEAR FROM year_quarter_start_date)::int = %s',
            p_source_table,
            v_max_year
        )
        INTO v_last_year_max_qtr;

    IF v_last_year_max_qtr IS NULL THEN
        RAISE EXCEPTION
            'Could not determine the maximum quarter for year % in %',
            v_max_year, p_source_table;
    END IF;

    -- Create quarterly partitions from v_min_year to v_max_year and quarters 1 to 4
    FOR year_val IN v_min_year..v_max_year LOOP
        FOR quarter_val IN 1..4 LOOP

            -- For the last year, do not create quarters beyond the detected maximum
            IF year_val = v_max_year AND quarter_val > v_last_year_max_qtr THEN
                CONTINUE;
            END IF;

            -- Start date of the quarter
            start_date := make_date(year_val, (quarter_val - 1) * 3 + 1, 1);

            -- End date = first day of the next quarter
            IF quarter_val = 4 THEN
                end_date := make_date(year_val + 1, 1, 1);
            ELSE
                end_date := make_date(year_val, quarter_val * 3 + 1, 1);
            END IF;

            -- Partition table name:
            --   schema same as parent
            --   name = <parent_name>_<YYYY>Q<q>
            table_name := format(
                '%I.%I_%sQ%s',
                split_part(p_parent_table, '.', 1),             -- parent schema
                split_part(p_parent_table, '.', 2),             -- parent base name
                year_val,
                quarter_val
            );

            sql_stmt := format(
                'CREATE TABLE %s PARTITION OF %s
                 FOR VALUES FROM (%L) TO (%L);',
                table_name,
                p_parent_table,
                start_date,
                end_date
            );

            RAISE NOTICE '%', sql_stmt;
            EXECUTE sql_stmt;
        END LOOP;
    END LOOP;
END;
$$;

-- 5. load the shape file for time zone boundaries

/*
In order to process the Flight Performance data, we need a valid time zone name for each airport.
The dimension table from OAI does not contain this data, so we have to load the time zone boundaries, 
and then update the airport history dimension: 
*/

-- Shape file for time zone boundaries was located here:
-- https://github.com/evansiroky/timezone-boundary-builder/releases/download/2023b/timezones-with-oceans.shapefile.zip
-- This is after the shape file was loaded via shp2pgsql command line tool:
-- shp2pgsql -I -s 4326 combined-shapefile-with-oceans.shp | psql -p 5432 -d aviation 

--select * from public."combined-shapefile-with-oceans" limit 10;
--alter table public."combined-shapefile-with-oceans" rename to timezone_boundaries;
