-- zed_meta.database_schema_descriptions_v
CREATE OR REPLACE VIEW zed_meta.database_schema_descriptions_v 
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

-- zed_meta.database_objects_v
CREATE OR REPLACE VIEW zed_meta.database_objects_v 
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

----Procedure for import csv
CREATE OR REPLACE PROCEDURE import_data_from_manifest(OUT files_imported INTEGER,
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

-- call for procedure

CALL import_data_from_manifest(
    0, 
    'air_oai_facts.airfare_survey_ticket_load',  -- target_table
    'DB1B/ticket/_manifest_ticket_csv.csv',      -- manifest_file
    'src-aviation',                              -- source_bucket
    'us-west-2',                                 -- region
    '(FORMAT CSV, DELIMITER '','', HEADER)'      -- format_options
);
