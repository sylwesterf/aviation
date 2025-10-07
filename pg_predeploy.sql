----------------------------------------------------
-- STEPS:
-- 0. create aviation database
-- 1. create schemas
-- 2. create pg extensions 
-- 3. create pg metadata views
-- 4. define stored procedures
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
GRANT rds_superuser TO aviation;
CREATE EXTENSION IF NOT EXISTS POSTGIS; -- extension needed for geometry data type in one of the tables in air_oai_dims
CREATE EXTENSION IF NOT EXISTS aws_s3 CASCADE; -- adds functions for importing data from an Amazon S3 (in Aurora)

-- test aws_s3 extension and rds-s3 connectivity (via table_import_from_s3 call)
create table test (id int, descr varchar(10));
SELECT aws_s3.table_import_from_s3('test','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/test_file.csv', 'us-west-2'));
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
JOIN pg_authid u ON c.relowner = u.oid
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

-- 4. define data load stored procedure - simplifies s3 data loads in aurora
CREATE OR REPLACE PROCEDURE import_data_from_manifest
(OUT 
    files_imported INTEGER,
    target_table TEXT,
    manifest_file TEXT,
    source_bucket TEXT,
    region TEXT DEFAULT 'us-west-2',
   format_options TEXT DEFAULT '(FORMAT CSV, DELIMITER '','', HEADER)'
) AS $$
DECLARE
    uri_record RECORD;
    temp_table_name TEXT := 'temp_manifest_' || md5(random()::text);
    error_count INTEGER := 0;
    total_files INTEGER;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    files_imported := 0;
    start_time := clock_timestamp();
    
    RAISE NOTICE '--- Starting import from manifest % to table % ---', manifest_file, target_table;
    
    -- Create a temporary table to store the manifest file contents
    EXECUTE format('CREATE TEMPORARY TABLE %s (file_uri TEXT)', quote_ident(temp_table_name));
    
    -- Import the manifest file into the temporary table
    PERFORM aws_s3.table_import_from_s3(
        temp_table_name,
        'file_uri',
        '(FORMAT CSV, HEADER false)',
        aws_commons.create_s3_uri(
            source_bucket,
            manifest_file,
            region
        )
    );
    
    -- Get total number of files to import
    EXECUTE format('SELECT COUNT(*) FROM %s WHERE TRIM(file_uri) <> %L', quote_ident(temp_table_name), '')
        INTO total_files;
    RAISE NOTICE 'Found % files to import in manifest', total_files;
    
    -- Loop through each URI in the manifest and import the data
    FOR uri_record IN EXECUTE format('SELECT TRIM(file_uri) AS file_uri FROM %s WHERE TRIM(file_uri) <> %L', quote_ident(temp_table_name), '') LOOP
        -- Import the file using the provided URI directly
        BEGIN
            PERFORM aws_s3.table_import_from_s3(
                target_table,
                '',  -- column names (empty means all columns)
                format_options,
                aws_commons.create_s3_uri(
                    source_bucket,
                    uri_record.file_uri,
                    region
                )
            );
            
            files_imported := files_imported + 1;
            RAISE NOTICE 'Imported file: %', uri_record.file_uri;
            
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            RAISE WARNING 'Error importing file %: %', uri_record.file_uri, SQLERRM;
        END;
    END LOOP;
    
    -- Drop the temporary table
    EXECUTE format('DROP TABLE IF EXISTS %s', quote_ident(temp_table_name));

    -- Vacuum target table
    EXECUTE format('VACUUM VERBOSE %s', quote_ident(target_table));

    end_time := clock_timestamp();
    
    -- Print summary information
    RAISE NOTICE '--- Import Summary ---';
    RAISE NOTICE 'Target table: %', target_table;
    RAISE NOTICE 'Files successfully imported: %', files_imported;
    RAISE NOTICE 'Files with errors: %', error_count;
    RAISE NOTICE 'Total execution time: % seconds', EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER;
    RAISE NOTICE '---------------------';
END;
$$ LANGUAGE plpgsql;

-- sample procedure call
CALL import_data_from_manifest(
    0, 
    'air_oai_facts.airfare_survey_ticket_load',  -- target_table
    'DB1B/ticket/_manifest_ticket_csv.csv',      -- manifest_file
    'src-aviation',                              -- source_bucket
    'us-west-2',                                 -- region
    '(FORMAT CSV, DELIMITER '','', HEADER)'      -- format_options
);

-- 5. load the shape file for time zone boundaries

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
