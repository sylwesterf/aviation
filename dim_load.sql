-- Aviation Support/Dimension Tables (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Aviation Support Tables
-- https://transtats.bts.gov/Tables.asp?QO_VQ=IMI&QO_anzr=N8vn6v10%FDf722146%FDgnoyr5&QO_fu146_anzr=N8vn6v10%FDf722146%FDgnoyr5

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files: AircraftTypes, Carrier Decode, Master Coordinate, World Area Codes
-- 1. create aircraft types lookup 
--  1.1. create air_oai_dims.aircraft_types_fdw table 
--  1.2. copy aircraft types data into air_oai_dims.aircraft_types_fdw
--  1.3. create air_oai_dims.aircraft_types table 
--  1.4. copy data into air_oai_dims.aircraft_types from air_oai_dims.aircraft_types_fdw
-- 2. create world areas lookup 
--  2.1. create air_oai_dims.wac_country_state_fdw table 
--  2.2. copy world areas data into air_oai_dims.wac_country_state_fdw
--  2.3. create air_oai_dims.world_areas table 
--  2.4. copy data into air_oai_dims.world_areas from air_oai_dims.wac_country_state_fdw
-- 3. create airline entities lookup 
--  3.1. create air_oai_dims.carrier_decode_fdw table 
--  3.2. copy aircraft types data into air_oai_dims.carrier_decode_fdw
--  3.3. create air_oai_dims.world_areas table 
--  3.4. copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw
--  3.4.1. copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for non '3KQ' airline oai codes
--  3.4.2. copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for '3KQ' airline oai codes
-- 4. create airport history lookup 
--  4.1. create air_oai_dims.master_cord_fdw table   
--  4.2. copy world areas data into air_oai_dims.master_cord_fdw
--  4.3. create air_oai_dims.airport_history table 
--  4.4. copy data into air_oai_dims.airport_history from air_oai_dims.master_cord_fdw
--  4.5. update world area keys in air_oai_dims.airport_history based on air_oai_dims.world_areas
--  4.6. update the time zone boundaries in air_oai_dims.airport_history 
-- 5. create aircraft types group lookup 
--  5.1. create air_oai_dims.aircraft_type_groups
--  5.2. load air_oai_dims.aircraft_type_groups from air_oai_dims.aircraft_types
-- 6. create airline entity group (new) lookup 
--  6.1. create air_oai_dims.airline_entity_new_groups
--  6.2. load air_oai_dims.airline_entity_new_groups from air_oai_dims.airline_entities
-- 7. create airport types group (legacy) lookup 
--  7.1. create air_oai_dims.airline_entity_legacy_groups
--  7.2. load air_oai_dims.airline_entity_legacy_groups from air_oai_dims.airline_entities
-- 8. create geographic types lookup (hardcoded)
-- 9. create airfare classes lookup (hardcoded)
-- 10. create traffic data sources lookup (hardcoded)
-- 11. define column comments
-- 12. create presentation layer views
----------------------------------------------------

-- 1.1. define a table we'll be copying the data to (alternatively use one of the FDW extension)
drop table if exists air_oai_dims.aircraft_types_fdw;
create table air_oai_dims.aircraft_types_fdw
( 
	aircraft_type_oai_nbr			smallint	not null
	, aircraft_group_oai_nbr		smallint	not null
	, aircraft_oai_type				varchar(55)	not null
	, manufacturer_name				varchar(55)
	, aircraft_type_long_name		varchar(55)	not null
	, aircraft_type_brief_name		varchar(55)	not null
	, aircraft_type_from_date		date		not null
	, aircraft_type_thru_date		date
);

-- 1.2. copy aircraft types data into air_oai_dims.aircraft_types_fdw
-- 1.2.1. mstr psql version of the data load
-- mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY air_oai_dims.aircraft_types_fdw FROM 'T_AIRCRAFT_TYPES.csv' CSV HEADER";
-- 1.2.2. AWS Aurora data load
SELECT aws_s3.table_import_from_s3('air_oai_dims.aircraft_types_fdw','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/DIMS/CSV/T_AIRCRAFT_TYPES.csv', 'us-west-2'));

-- 1.3. define final dimensional table air_oai_dims.aircraft_types
drop table if exists air_oai_dims.aircraft_types;
create table air_oai_dims.aircraft_types
( 
	aircraft_type_oai_nbr			smallint	not null
	, aircraft_group_oai_nbr		smallint	not null
	, aircraft_oai_type				varchar(55)	not null
	, manufacturer_name				varchar(55)	not null
	, aircraft_type_long_name		varchar(55)	not null
	, aircraft_type_brief_name		varchar(55)	not null
	, aircraft_type_from_date		date		not null
	, aircraft_type_thru_date		date
	, created_by					varchar(32) not null default current_user
	, created_tmst					timestamp(0) not null default current_timestamp
	, updated_by					varchar(32)
	, updated_tsmt					timestamp(0)
	, constraint aircraft_types_pk primary key (aircraft_type_oai_nbr)
);

-- 1.4. copy data into air_oai_dims.aircraft_types from air_oai_dims.aircraft_types_fdw
insert into air_oai_dims.aircraft_types
( 
	aircraft_type_oai_nbr
	, aircraft_group_oai_nbr
	, aircraft_oai_type
	, manufacturer_name
	, aircraft_type_long_name
	, aircraft_type_brief_name
	, aircraft_type_from_date
	, aircraft_type_thru_date
	, created_by
	, created_tmst
)
select f.aircraft_type_oai_nbr
	 , f.aircraft_group_oai_nbr
	 , f.aircraft_oai_type
	 , case when f.manufacturer_name is null then 'GENERIC' else f.manufacturer_name end as manufacturer_name
	 , f.aircraft_type_long_name
	 , f.aircraft_type_brief_name
	 , f.aircraft_type_from_date
	 , f.aircraft_type_thru_date
	 , current_user
     , current_timestamp
from air_oai_dims.aircraft_types_fdw f
--left outer join air_oai_dims.aircraft_types t on f.aircraft_type_oai_nbr = t.aircraft_type_oai_nbr
--where t.aircraft_type_oai_nbr is null;


-- 2.1. create air_oai_dims.wac_country_state_fdw table 
DROP TABLE IF EXISTS air_oai_dims.wac_country_state_fdw;
CREATE TABLE air_oai_dims.wac_country_state_fdw
( 
	world_area_oai_id					integer
	, world_area_oai_seq_id				integer
	, world_area_name					varchar(125)
	, world_region_name					varchar(125)
	, country_short_name				varchar(75)
	, country_type_descr				varchar(75)
	, capital_city_name					varchar(75)
	, sovereign_country_name			varchar(75)
	, country_iso_code					char(2)
	, subdivision_iso_code				varchar(10)
	, subdivision_name					varchar(75)
	, subdivision_fips_code				varchar(10)
	, effective_from_date				date
	, effective_thru_date				date
	, comments_text						varchar(555)
	, world_area_latest_ind				smallint
);

-- 2.2. copy aircraft types data into air_oai_dims.aircraft_types_fdw
-- 2.2.1 mstr psql version of the data load
--mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY air_oai_dims.wac_country_state_fdw FROM 'T_WAC_COUNTRY_STATE.csv' CSV HEADER";
-- 2.2.2 AWS Aurora data load
SELECT aws_s3.table_import_from_s3('air_oai_dims.wac_country_state_fdw','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/DIMS/CSV/T_WAC_COUNTRY_STATE.csv', 'us-west-2')); 

-- 2.3. define final dimensional table air_oai_dims.world_areas
drop table if exists air_oai_dims.world_areas;
create table air_oai_dims.world_areas
( 
	world_area_oai_seq_id				integer			not null
	, world_area_key					char(32)		not null
	, world_area_oai_id					smallint		not null
	, effective_from_date				date			not null
	, effective_thru_date				date
	, world_area_latest_ind				smallint
	, world_area_name					varchar(125)
	, world_region_name					varchar(125)
	, subdivision_iso_code				varchar(10)
	, subdivision_fips_code				varchar(10)
	, subdivision_name					varchar(75)
	, country_iso_code					char(2)
	, country_short_name				varchar(75)
	, country_type_descr				varchar(75)
	, sovereign_country_name			varchar(75)
	, capital_city_name					varchar(75)
	, world_area_comments_text			varchar(555)
	, created_by						varchar(32) 	not null default current_user
	, created_tmst						timestamp(0) 	not null default current_timestamp
	, updated_by						varchar(32)
	, updated_tsmt						timestamp(0)
	, constraint world_areas_pk primary key (world_area_oai_seq_id)
	, constraint world_areas_ak unique (world_area_key)
	, constraint world_areas_nk unique (world_area_oai_id, effective_from_date)
);


-- 2.4. copy data into air_oai_dims.world_areas from air_oai_dims.wac_country_state_fdw
INSERT INTO air_oai_dims.world_areas
( 
	world_area_oai_seq_id
	, world_area_key
	, world_area_oai_id
	, effective_from_date
	, effective_thru_date
	, world_area_latest_ind
	, world_area_name
	, world_region_name
	, subdivision_iso_code
	, subdivision_fips_code
	, subdivision_name
	, country_iso_code
	, country_short_name
	, country_type_descr
	, sovereign_country_name
	, capital_city_name
	, world_area_comments_text
	, created_by
	, created_tmst
)
SELECT 
       world_area_oai_seq_id
     , md5(world_area_oai_id ||'~'||(effective_from_date::text)) as world_area_key
     , world_area_oai_id
	 , effective_from_date
	 , effective_thru_date
	 , world_area_latest_ind
	 , world_area_name
	 , world_region_name
	 , subdivision_iso_code
	 , subdivision_fips_code
	 , subdivision_name
	 , country_iso_code
	 , country_short_name
	 , country_type_descr
	 , sovereign_country_name
	 , capital_city_name
     , comments_text
	 , current_user
	 , current_timestamp
FROM air_oai_dims.wac_country_state_fdw;


-- 3.1. create air_oai_dims.carrier_decode_fdw table 
drop table if exists air_oai_dims.carrier_decode_fdw;
CREATE TABLE air_oai_dims.carrier_decode_fdw
( 
	airline_usdot_id				smallint
	, airline_oai_code				varchar(10)
	, entity_oai_code				varchar(10)
	, airline_name					varchar(125)
	, airline_unique_oai_code		varchar(10)
	, entity_unique_oai_code		varchar(10)
	, airline_unique_name			varchar(125)
	, world_area_oai_id			smallint
	, airline_old_group_nbr			smallint
	, airline_new_group_nbr			smallint		
	, operating_region_code			varchar(25)			
	, source_from_date				date
	, source_thru_date				date
);

-- 3.2. copy aircraft types data into air_oai_dims.carrier_decode_fdw
-- 3.2.1 mstr psql version of the data load
--mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY air_oai_dims.carrier_decode_fdw FROM 'T_CARRIER_DECODE.csv' CSV HEADER";
-- 3.2.2 AWS Aurora data load
SELECT aws_s3.table_import_from_s3('air_oai_dims.carrier_decode_fdw','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/DIMS/CSV/T_CARRIER_DECODE.csv', 'us-west-2')); 

-- 3.3. create air_oai_dims.airline_entities table 
drop table if exists air_oai_dims.airline_entities;
create table air_oai_dims.airline_entities
( 
	airline_entity_id				smallint 	not null generated by default as identity
	, airline_entity_key			char(32) 	not null -- md5 hash of natural key <'airline_oai_code'|'entity_oai_code'|'source_from_date'>
	, airline_usdot_id				smallint	not null -- airline_usdot_id
	, airline_oai_code				varchar(10)	not null -- carrier_oai_code
	, entity_oai_code				varchar(10) not null -- carrier_entity_code
	, airline_name					varchar(125) not null -- carrier_nm
	, airline_unique_oai_code		varchar(10)	not null -- unique_carrier_code
	, entity_unique_oai_code		varchar(10)	not null -- unique_carrier_entity_code
	, airline_unique_name			varchar(125) not null -- unique_carrier_name
	, world_area_oai_id				smallint	not null -- airline_world_area_oai_code
	, world_area_oai_seq_id			integer		null	 -- this must be the actual FK, since the ID is not unique
	, airline_old_group_nbr			smallint	not null -- carrier_old_group_nbr
	, airline_new_group_nbr			smallint	not null -- carrier_new_group_nbr
	, operating_region_code			varchar(25)	not null -- operating_region_code
	, source_from_date				date		not null -- source_from_date
	, source_thru_date				date			     -- source_thru_date
	, created_by					varchar(32) not null default current_user
	, created_tmst					timestamp(0) not null default current_timestamp
	, updated_by					varchar(32)
	, updated_tsmt					timestamp(0)
	, constraint airline_entities_pk primary key (airline_entity_id)
	, constraint airline_entities_ak unique (airline_entity_key)
	, constraint airline_entities_nk unique (airline_oai_code, entity_oai_code, source_from_date)
);

-- TODO - drop identity - check if needed and why, was starting at 4000 before? - identity dropped before data load - throws error on data insert (step 3.5.1)
-- alter table air_oai_dims.airline_entities alter column airline_entity_id drop identity;

-- 3.4. copy data into air_oai_dims.airline_entities from air_oai_dims.carrier_decode_fdw
-- 3.4.1 copy data into air_oai_dims.airline_entities from air_oai_dims.carrier_decode_fdw for non '3KQ' airline oai codes
insert into air_oai_dims.airline_entities
( 
	airline_entity_key
	, airline_usdot_id
	, airline_oai_code
	, entity_oai_code
	, airline_name
	, airline_unique_oai_code
	, entity_unique_oai_code
	, airline_unique_name
	, world_area_oai_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	, source_from_date
	, source_thru_date
	, created_by
	, created_tmst
)
select md5(f.airline_oai_code||'~'||f.entity_oai_code||'~'||f.source_from_date::char(10)) as airline_entity_key
    , f.airline_usdot_id
	, f.airline_oai_code
	, f.entity_oai_code
	, f.airline_name
	, f.airline_unique_oai_code
	, f.entity_unique_oai_code
	, f.airline_unique_name
	, f.world_area_oai_id
	, f.airline_old_group_nbr
	, f.airline_new_group_nbr
	, f.operating_region_code
	, f.source_from_date
	, f.source_thru_date
	, current_user
	, current_timestamp
from air_oai_dims.carrier_decode_fdw f
--left outer join air_oai_dims.airline_entities e on f.airline_oai_code = e.airline_oai_code and f.entity_oai_code = e.entity_oai_code and f.source_from_date = e.source_from_date
where --e.airline_oai_code is null and 
f.airline_oai_code != '3KQ' -- this code or set of codes was found to be non-unique
order by f.airline_usdot_id, f.airline_oai_code, f.entity_oai_code, f.source_from_date;

-- 3.4.2 copy data into air_oai_dims.airline_entities from air_oai_dims.carrier_decode_fdw for '3KQ' airline oai codes
insert into air_oai_dims.airline_entities
( 
	airline_entity_key
	, airline_usdot_id
	, airline_oai_code
	, entity_oai_code
	, airline_name
	, airline_unique_oai_code
	, entity_unique_oai_code
	, airline_unique_name
	, world_area_oai_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	, source_from_date
	, source_thru_date
	, created_by
	, created_tmst
)
select md5(airline_oai_code||'~'||entity_oai_code||'~'||source_from_date::char(10)) as airline_entity_key
    , airline_usdot_id
	, airline_oai_code
	, entity_oai_code
	, airline_name
	, airline_unique_oai_code
	, entity_unique_oai_code
	, airline_unique_name
	, world_area_oai_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	, source_from_date
	, source_thru_date
	, current_user
	, current_timestamp
from 
(
	select max(f.airline_usdot_id) as airline_usdot_id
		, f.airline_oai_code
		, f.entity_oai_code
		, max(f.airline_name) as airline_name
		, max(f.airline_unique_oai_code) as airline_unique_oai_code
		, max(f.entity_unique_oai_code) as entity_unique_oai_code
		, max(f.airline_unique_name) as airline_unique_name
		, max(f.world_area_oai_id) as world_area_oai_id
		, max(f.airline_old_group_nbr) as airline_old_group_nbr
		, max(f.airline_new_group_nbr) as airline_new_group_nbr
		, max(f.operating_region_code) as operating_region_code
		, f.source_from_date
		, max(f.source_thru_date) as source_thru_date
	from air_oai_dims.carrier_decode_fdw f
	where f.airline_oai_code = '3KQ'
	group by airline_oai_code, entity_oai_code, source_from_date
) x;


-- 4.1. create air_oai_dims.master_cord_fdw table   
DROP TABLE IF EXISTS air_oai_dims.master_cord_fdw;
CREATE TABLE air_oai_dims.master_cord_fdw 
( 
	airport_oai_seq_id						integer
	, airport_oai_id						integer
	, airport_oai_code						varchar(3)
	, airport_display_name					varchar(125)
	, city_full_display_name				varchar(125)
	, airport_world_area_oai_seq_id			integer
	, airport_world_area_oai_id				integer
	, country_name							varchar(75)
	, country_iso_code						varchar(10)
	, subdivision_name						varchar(75)
	, subdivision_iso_code					varchar(10)
	, subdivision_fips_code					varchar(10)
	, market_city_oai_seq_id				integer
	, market_city_oai_id					integer
	, market_city_full_display_name			varchar(75)
	, market_city_world_area_oai_seq_id		integer
	, market_city_world_area_oai_id			integer
	, latitude_degrees						smallint
	, latitude_hemisphere_code				char(1)
	, latitude_minutes						smallint
	, latitude_seconds						smallint
	, latitude_decimal_nbr					numeric(9,7)
	, longitude_degrees						smallint
	, longitude_hemisphere_code				char(1)
	, longitude_minutes						smallint
	, longitude_seconds						smallint
	, longitude_decimal_nbr					numeric(10,7)
	, utc_local_time_variation				varchar(75)
	, airport_effective_from_date			date
	, airport_effective_thru_date			date
	, airport_closed_ind					smallint
	, airport_latest_ind					smallint
);

-- 4.2. copy world areas data into air_oai_dims.master_cord_fdw
-- 4.2.1 mstr psql version of the data load
--mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY air_oai_dims.master_cord_fdw FROM 'T_MASTER_CORD.csv' CSV HEADER";
-- 4.2.2 AWS Aurora data load
SELECT aws_s3.table_import_from_s3('air_oai_dims.master_cord_fdw','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/DIMS/CSV/T_MASTER_CORD.csv', 'us-west-2')); 

-- 4.3. create air_oai_dims.airport_history table 
drop table if exists air_oai_dims.airport_history;
CREATE TABLE air_oai_dims.airport_history 
( 
	airport_history_id 					integer NOT NULL generated by default as identity
	, airport_history_key 					char(32) NOT NULL
	, airport_oai_code 						varchar(3) NOT NULL
	, effective_from_date 					date NOT NULL
	, effective_thru_date 					date
	, airport_closed_ind 					smallint NOT NULL
	, airport_latest_ind 					smallint NOT NULL
	, airport_oai_seq_id 					integer NOT NULL
	, airport_oai_id 						integer NOT NULL
	, airport_display_name 					varchar(125) NOT NULL
	, city_full_display_name 				varchar(125) NOT NULL
	, airport_world_area_oai_seq_id 		integer NOT NULL
	, airport_world_area_oai_id 			integer NOT NULL
	, airport_world_area_key				char(32)
	, utc_local_time_variation 				char(5)
	, time_zone_name 						varchar(100)
	, market_city_oai_seq_id 				integer NOT NULL
	, market_city_oai_id 					integer NOT NULL
	, market_city_full_display_name 		varchar(75) NOT NULL
	, market_city_world_area_oai_seq_id 	integer NOT NULL
	, market_city_world_area_oai_id 		integer NOT NULL
	, market_city_world_area_key			char(32)
	, subdivision_iso_code 					varchar(10)
	, subdivision_fips_code 				varchar(10)
	, subdivision_name 						varchar(75)
	, country_iso_code 						varchar(10)  -- NOT NULL
	, country_name 							varchar(75) NOT NULL
	, latitude_decimal_nbr 					numeric(9,7)
	, longitude_decimal_nbr 				numeric(10,7)
	, point_geom 							geometry
	, created_by 							varchar(32) DEFAULT CURRENT_USER NOT NULL
	, created_tmst 							timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL
	, updated_by 							varchar(32)
	, updated_tsmt 							timestamp
	, constraint airport_history_pk primary key (airport_history_id)
	, constraint airport_history_ak unique (airport_history_key)
	, constraint airport_history_nk unique (airport_oai_code, effective_from_date)
);
-- TODO verify -> alter table air_oai_dims.airport_history alter column airport_history_id drop identity;

-- 4.4. copy data into air_oai_dims.airport_history from air_oai_dims.master_cord_fdw
INSERT INTO air_oai_dims.airport_history
( 
	airport_history_key
	, airport_oai_code
	, effective_from_date
	, effective_thru_date
	, airport_closed_ind
	, airport_latest_ind
	, airport_oai_seq_id
	, airport_oai_id
	, airport_display_name
	, city_full_display_name
	, airport_world_area_oai_seq_id
	, airport_world_area_oai_id
	, utc_local_time_variation -- time_zone_name
	, market_city_oai_seq_id
	, market_city_oai_id
	, market_city_full_display_name
	, market_city_world_area_oai_seq_id
	, market_city_world_area_oai_id
	, subdivision_iso_code
	, subdivision_fips_code
	, subdivision_name
	, country_iso_code
	, country_name
	, latitude_decimal_nbr
	, longitude_decimal_nbr
	, point_geom
	, created_by
	, created_tmst
)
SELECT md5(upper(m.airport_oai_code)||'~'||m.airport_effective_from_date::char(10)) as airport_history_key
    , m.airport_oai_code
    , m.airport_effective_from_date
	, m.airport_effective_thru_date
	, m.airport_closed_ind
	, m.airport_latest_ind
    , m.airport_oai_seq_id
	, m.airport_oai_id
	, m.airport_display_name
	, m.city_full_display_name
	, m.airport_world_area_oai_seq_id
	, m.airport_world_area_oai_id
	, case when length(m.utc_local_time_variation) = 0 then null else m.utc_local_time_variation end as utc_local_time_variation
	, m.market_city_oai_seq_id
	, m.market_city_oai_id
	, m.market_city_full_display_name
	, m.market_city_world_area_oai_seq_id
	, m.market_city_world_area_oai_id
	, m.subdivision_iso_code
	, m.subdivision_fips_code
	, m.subdivision_name
	, m.country_iso_code
	, m.country_name
	, m.latitude_decimal_nbr
	, m.longitude_decimal_nbr
	, case when m.latitude_decimal_nbr is not null and m.longitude_decimal_nbr is not null 
	      then ST_SetSRID(ST_MakePoint(m.longitude_decimal_nbr, m.latitude_decimal_nbr),4326)
	      else null end as point_geom
	, current_user
	, current_timestamp
FROM air_oai_dims.master_cord_fdw m
--left join air_oai_dims.airport_history h 
--  on m.airport_oai_code = h.airport_oai_code 
-- and m.airport_effective_from_date = h.effective_from_date
--where h.airport_oai_code is null;

-- 4.5 update world area keys in air_oai_dims.airport_history based on air_oai_dims.world_areas  
update air_oai_dims.airport_history
set  -- airport_world_area_id = abc.airport_world_area_id 
    airport_world_area_key = abc.airport_world_area_key
  --, market_city_world_area_id = abc.market_city_world_area_id
  , market_city_world_area_key = abc.market_city_world_area_key
from 
(
	select a.airport_history_id, a.airport_history_key
		 , a.airport_oai_code, a.effective_from_date
		 , a.subdivision_iso_code, a.country_iso_code
		 , a.airport_world_area_oai_id
		 , a.airport_world_area_oai_seq_id
		 --, b.world_area_id as airport_world_area_id
		 , b.world_area_key as airport_world_area_key
		 , a.market_city_world_area_oai_id
		 , a.market_city_world_area_oai_seq_id
		 --, c.world_area_id as market_city_world_area_id
		 , c.world_area_key as market_city_world_area_key
	from air_oai_dims.airport_history a 
	left outer join air_oai_dims.world_areas b
	  on a.airport_world_area_oai_id = b.world_area_oai_id
	 and a.airport_world_area_oai_seq_id = b.world_area_oai_seq_id
	left outer join air_oai_dims.world_areas c
	  on a.market_city_world_area_oai_id = c.world_area_oai_id
	 and a.market_city_world_area_oai_seq_id = c.world_area_oai_seq_id
) abc 
where air_oai_dims.airport_history.airport_history_id = abc.airport_history_id
and air_oai_dims.airport_history.airport_history_key = abc.airport_history_key;


-- 4.6. update the time zone boundaries in air_oai_dims.airport_history 
update air_oai_dims.airport_history
set	
	time_zone_name = c.time_zone_name
	, updated_by = current_user
	, updated_tsmt = current_timestamp
from (
select a.airport_history_id, a.airport_oai_code, a.effective_from_date, b.time_zone_name 
from (select airport_history_id, airport_oai_code, effective_from_date, point_geom 
      from air_oai_dims.airport_history where time_zone_name is null /*limit 10000*/) a
cross join (select gid, tzid as time_zone_name, geom as time_zone_geom from public.timezone_boundaries) b
where ST_Contains(b.time_zone_geom, a.point_geom) is true
) c
where air_oai_dims.airport_history.airport_history_id = c.airport_history_id
and air_oai_dims.airport_history.time_zone_name is null;


-- 5.1. create air_oai_dims.aircraft_type_groups
drop table if exists air_oai_dims.aircraft_type_groups;
create table air_oai_dims.aircraft_type_groups
(
  aircraft_group_oai_nbr smallint not null,
  descr varchar(55) not null,
  long_descr varchar(255) not null,
  created_by varchar(32) not null,
  created_ts timestamp not null
);

-- 5.2. load air_oai_dims.aircraft_type_groups from air_oai_dims.aircraft_types
insert into air_oai_dims.aircraft_type_groups
(
	aircraft_group_oai_nbr
	, descr
	, long_descr
	, created_by
	, created_ts
)
select distinct coalesce( aircraft_group_oai_nbr, -1) as aircraft_group_oai_nbr
  ,case aircraft_group_oai_nbr
    when 0 then 'Piston, 1 Engine'
    when 1 then 'Piston, 2 Engines'
    when 2 then 'Piston, 3-4 Engine'
    when 3 then 'Helicopter/STOL'
    when 4 then 'Turbo-Prop, 1-2 Engines'
    when 5 then 'Turbo-Prop, 4 Engines'
    when 6 then 'Jet, 2 Engines'
    when 7 then 'Jet, 3 Engines'
    when 8 then 'Jet, 4-6 Engines'
    when 9 then 'Expenses'
    else 'UNK'
  end as descr
  ,case aircraft_group_oai_nbr
    when 0 then 'Piston, 1-Engine/Combined Single Engine (Piston/Turbine)'
    when 1 then 'Piston, 2-Engine'
    when 2 then 'Piston, 3-Engine/4-Engine'
    when 3 then 'Helicopter/Short-Take-Off-Landing'
    when 4 then 'TTurbo-Prop, 1-Engine/2-Engine'
    when 5 then 'Turbo-Prop, 4-Engine'
    when 6 then 'Jet, 2-Engines'
    when 7 then 'Jet, 3 Engines'
    when 8 then 'Jet, 4-Engine/6-Engine'
    when 9 then 'Used for capturing expenses not attributed to specific aircraft types'
    else 'UNK'
  end as long_descr
  ,current_user as created_by
  ,current_timestamp as created_ts
from air_oai_dims.aircraft_types;

-- 6.1. create air_oai_dims.airline_new_group_nbr
drop table if exists air_oai_dims.airline_entity_new_groups;
create table air_oai_dims.airline_entity_new_groups
(
  airline_new_group_nbr smallint not null,
  descr varchar(55) not null,
  long_descr varchar(255) not null,
  created_by varchar(32) not null,
  created_ts timestamp not null
);

-- 6.2. load air_oai_dims.airline_entity_new_groups from air_oai_dims.airline_entities
insert into air_oai_dims.airline_entity_new_groups
(
  airline_new_group_nbr
  , descr
  , long_descr
  , created_by
  , created_ts
)
select distinct coalesce(airline_new_group_nbr, -1) as airline_new_group_nbr
       ,CASE airline_new_group_nbr
            WHEN 0 THEN 'Foreign'
            WHEN 1 THEN 'Large Regional'
            WHEN 2 THEN 'National'
            WHEN 3 THEN 'Major'
            WHEN 4 THEN 'Medium'
            WHEN 5 THEN 'Small, Certified'
            WHEN 6 THEN 'Commuter, Large'
            WHEN 7 THEN 'All Cargo'
            WHEN 9 THEN 'Commuter, Essential'
            ELSE 'UNK'
        END AS descr
        ,CASE airline_new_group_nbr
            WHEN 0 THEN 'Foreign Carriers'
            WHEN 1 THEN 'Large Regional Carriers (carriers with annual revenue of $20 million to $100 million))'
            WHEN 2 THEN 'National Carriers (carriers with annual revenue over 100 milion to 1 billion)'
            WHEN 3 THEN 'Major Carriers (carriers with annual revenue over $1 billion'
            WHEN 4 THEN 'Medium Regional Carriers (carriers with annual revenue under $20 million)'
            WHEN 5 THEN 'Small Certificated Carriers (carrier holding certificate issued under 49 U.S.C. section 41101 and operating aircraft designed to have a maximum seating capacity of 60 or less seat or a maximum payload of 18,000 pounds or less.)'
            WHEN 6 THEN 'Commuter Carriers (air taxi operator which performs at least five round trips per week between two or more points and publishes flight schedules which specify the times, days of the weeks and plans between which such flights are performed.'
            WHEN 7 THEN 'All Cargo Carriers operating under cerificates issued under 49 U.S.C. section 41103'
            WHEN 9 THEN 'Commuter Carriers (Air Taxi providing Essential Air Service)'
            ELSE 'UNK'
        END AS long_descr
        ,current_user as created_by
        ,current_timestamp as created_ts
from air_oai_dims.airline_entities;

-- 7.1. create air_oai_dims.airline_entity_legacy_groups
drop table if exists air_oai_dims.airline_entity_legacy_groups;
create table air_oai_dims.airline_entity_legacy_groups
(
  airline_old_group_nbr smallint not null,
  descr varchar(55) not null,
  long_descr varchar(255) not null,
  created_by varchar(32) not null,
  created_ts timestamp not null
);

-- 7.2. load air_oai_dims.airline_entity_legacy_groups from air_oai_dims.airline_entities
insert into air_oai_dims.airline_entity_legacy_groups
(
  airline_old_group_nbr
  , descr
  , long_descr
  , created_by
  , created_ts
)
select distinct coalesce(airline_old_group_nbr, -1) as airline_old_group_nbr
      ,CASE airline_old_group_nbr
          WHEN 0 THEN 'International'
          WHEN 1 THEN 'Regional'
          WHEN 2 THEN 'National'
          WHEN 3 THEN 'Major'
          WHEN 7 THEN 'All Cargo'
          ELSE 'UNK'
      END AS descr
      ,CASE airline_old_group_nbr
          WHEN 0 THEN 'International Carriers'
          WHEN 1 THEN 'Regional Carriers (including Large, Medium, Commuter, Small Certified)'
          WHEN 2 THEN 'National Carriers'
          WHEN 3 THEN 'Major Carriers'
          WHEN 7 THEN 'Domestic Only - All Cargo Carriers'
          ELSE 'UN'
      END AS long_descr
      ,current_user as created_by
      ,current_timestamp as created_ts
from air_oai_dims.airline_entities;

-- 8. create air_oai_dims.airline_geographic_types 
drop table if exists air_oai_dims.airline_geographic_types;
create table air_oai_dims.airline_geographic_types
as
select 0::smallint as geograhic_type_oai_id, 'International'::varchar(35) as descr, 'International travel between indepedent soverign states.'::varchar(255) as long_descr union
select 1::smallint as geograhic_type_oai_id, 'Domestic, Global'::varchar(35) as descr, 'Domestic Non-contiguous (Includes Hawaii, Alaska and Territories)'::varchar(255) as long_descr union
select 2::smallint as geograhic_type_oai_id, 'Domestic, Lower48'::varchar(35) as descr, 'Domestic Contiguous (Lower 48 U.S. States Only)'::varchar(255) as long_descr
order by 1;

-- 9. create air_oai_dims.airfare_classes 
drop table if exists air_oai_dims.airfare_classes;
create table air_oai_dims.airfare_classes
as
select '-'::char(1) as airfare_class_code, 'Ground'::varchar(35) as descr, 'Ground Segment'::varchar(255) as long_descr union
select 'C'::char(1) as airfare_class_code, 'Biz Unl'::varchar(35) as descr, 'Unrestricted Business Class'::varchar(255) as long_descr union
select 'D'::char(1) as airfare_class_code, 'Biz Lim'::varchar(35) as descr, 'Restricted Business Class'::varchar(255) as long_descr union
select 'F'::char(1) as airfare_class_code, 'First Unl'::varchar(35) as descr, 'Unrestricted First Class'::varchar(255) as long_descr union
select 'G'::char(1) as airfare_class_code, 'First Lim'::varchar(35) as descr, 'Restricted First Class'::varchar(255) as long_descr union
select 'U'::char(1) as airfare_class_code, 'Unk'::varchar(35) as descr, 'Unknown'::varchar(255) as long_descr union
select 'X'::char(1) as airfare_class_code, 'Econ Lim'::varchar(35) as descr, 'Restricted Coach Class'::varchar(255) as long_descr union
select 'Y'::char(1) as airfare_class_code, 'Econ Unl'::varchar(35) as descr, 'Unrestricted Coach Class'::varchar(255) as long_descr
order by 1;

-- 10. create air_oai_dims.airline_traffic_data_sources
drop table if exists air_oai_dims.airline_traffic_data_sources;
create table air_oai_dims.airline_traffic_data_sources
as
select 'DF'::varchar(5) as service_class_code, 'DOM, INTL carrier'::varchar(55) as descr, 'Domestic Data, Foreign Carriers'::varchar(255) as long_descr union
select 'DU'::varchar(5) as service_class_code, 'DOM, US carrier'::varchar(55) as descr, 'Domestic Data, US Carriers Only'::varchar(255) as long_descr union
select 'IF'::varchar(5) as service_class_code, 'INTL, INTL carrier'::varchar(55) as descr, 'International Data, Foreign Carriers'::varchar(255) as long_descr union
select 'IU'::varchar(5) as service_class_code, 'INTL, US carrier'::varchar(55) as descr, 'International Data, US Carriers Only'::varchar(255) as long_descr
order by 1;

-- 11. define column comments
-- air_oai_dims.aircraft_types
comment on column air_oai_dims.aircraft_types.aircraft_type_oai_nbr is 'AC_TYPEID = Aircraft Type Identification Number. This Number Is Related To The Aircraft Group Number And Falls Within The Range Of A Group Number.';
comment on column air_oai_dims.aircraft_types.aircraft_group_oai_nbr is 'AC_GROUP = Aircraft Type Group - This Number Gives The Group Or Classification Of Aircraft Engine And Type Of Aircraft.';
comment on column air_oai_dims.aircraft_types.aircraft_oai_type is 'SSD_NAME = Aircraft Name.';
comment on column air_oai_dims.aircraft_types.manufacturer_name is 'MANUFACTURER = Manufacturing Company Name.';
comment on column air_oai_dims.aircraft_types.aircraft_type_long_name is 'LONG_NAME = Complete Name Of The Aircraft.';
comment on column air_oai_dims.aircraft_types.aircraft_type_brief_name is 'SHORT_NAME = Abbreviated Name Of The Aircraft.';
comment on column air_oai_dims.aircraft_types.aircraft_type_from_date is 'BEGIN_DATE = The Date When The Aircraft Was Added To The Database.';
comment on column air_oai_dims.aircraft_types.aircraft_type_thru_date is 'END_DATE = The Date Through Which Aircraft Type Remains In Effect.';

-- air_oai_dims.world_areas
comment on column air_oai_dims.world_areas.world_area_key is 'MD5-hashed unique key of [world_area_oai_id & ~ & effective_from_date]';
comment on column air_oai_dims.world_areas.world_area_oai_id is 'WAC = World Area Code.';
comment on column air_oai_dims.world_areas.world_area_oai_seq_id is 'WAC_SEQ_ID2 = Unique Identifier for a World Area Code (WAC) at a given point of time.  WAC attributes may change over time.  For example the country name associated with the WAC can change, but the WAC code stays the same.';
comment on column air_oai_dims.world_areas.world_area_name is 'WAC_NAME = World Area Code Name.';
comment on column air_oai_dims.world_areas.world_region_name is 'WORLD_AREA_NAME = Geographic Region of World Area Code.';
comment on column air_oai_dims.world_areas.country_short_name is 'COUNTRY_SHORT_NAME = Country Name.';
comment on column air_oai_dims.world_areas.country_type_descr is 'COUNTRY_TYPE = Country Type.';
comment on column air_oai_dims.world_areas.capital_city_name is 'CAPITAL = Capital.';
comment on column air_oai_dims.world_areas.sovereign_country_name is 'SOVEREIGNTY = Sovereignty.';
comment on column air_oai_dims.world_areas.country_iso_code is 'COUNTRY_CODE_ISO = Two-Character ISO Country Code.';
comment on column air_oai_dims.world_areas.subdivision_iso_code is 'STATE_CODE = State Abbreviation.';
comment on column air_oai_dims.world_areas.subdivision_name is 'STATE_NAME = State Name.';
comment on column air_oai_dims.world_areas.subdivision_fips_code is 'STATE_FIPS = FIPS (Federal Information Processing Standard) State Code.';
comment on column air_oai_dims.world_areas.effective_from_date is 'START_DATE = Start Date of World Area Code Attributes.';
comment on column air_oai_dims.world_areas.effective_thru_date is 'THRU_DATE = End Date of World Area Code Attributes (Active = NULL).';
comment on column air_oai_dims.world_areas.world_area_comments_text is 'COMMENTS = Comments.';
comment on column air_oai_dims.world_areas.world_area_latest_ind is 'IS_LATEST = Indicates if this row contains the latest attributes for the World Area Code (1 = Yes).';

-- air_oai_dims.airline_entities
comment on column air_oai_dims.airline_entities.airline_entity_id is 'PostgreSQL defined identity surrogate key for high performance joins. Start with 4000.';
comment on column air_oai_dims.airline_entities.airline_entity_key is 'md5 hash of natural key <carrier_oai_code|entity_oai_code|source_from_date>.';
comment on column air_oai_dims.airline_entities.airline_usdot_id is 'AIRLINE_ID = An identification number assigned by US DOT to identify a unique airline (carrier). A unique airline (carrier) is defined as one holding and reporting under the same DOT certificate regardless of its Code, Name, or holding company/corporation.';
comment on column air_oai_dims.airline_entities.airline_oai_code is 'CARRIER = Code assigned by IATA and commonly used to identify a carrier. As the same code may have been assigned to different carriers over time, the code is not always unique.';
comment on column air_oai_dims.airline_entities.entity_oai_code is 'CARRIER_ENTITY = Carrier Entity.';
comment on column air_oai_dims.airline_entities.airline_name is 'CARRIER_NAME = Carrier Name.';
comment on column air_oai_dims.airline_entities.airline_unique_oai_code is 'UNIQUE_CARRIER = Unique Carrier Code. When the same code has been used by multiple carriers, a numeric suffix is used for earlier users, for example, PA, PA(1), PA(2). Use this field for analysis across a range of years.';
comment on column air_oai_dims.airline_entities.entity_unique_oai_code is 'UNIQUE_CARRIER_ENTITY = Unique Entity for a Carrier''s Operation Region.';
comment on column air_oai_dims.airline_entities.airline_unique_name is 'UNIQUE_CARRIER_NAME = Unique Carrier Name. When the same name has been used by multiple carriers, a numeric suffix is used for earlier users, for example, Air Caribbean, Air Caribbean (1).';
comment on column air_oai_dims.airline_entities.world_area_oai_id is 'WAC = World Area Code, this is a non-unique ID that represents a WAC.';
comment on column air_oai_dims.airline_entities.world_area_oai_seq_id is 'WAC = World Area Code, this is actual FK, since it is unique over time.';
comment on column air_oai_dims.airline_entities.airline_old_group_nbr is 'CARRIER_GROUP = Carrier Group Code.  Used in Legacy Analysis.';
comment on column air_oai_dims.airline_entities.airline_new_group_nbr is 'CARRIER_GROUP_NEW = Carrier Group New.';
comment on column air_oai_dims.airline_entities.operating_region_code is 'REGION = Carrier''s Operation Region. Carriers Report Data by Operation Region.';
comment on column air_oai_dims.airline_entities.source_from_date is 'START_DATE_SOURCE = Starting Date of Carrier Code.';
comment on column air_oai_dims.airline_entities.source_thru_date is 'THRU_DATE_SOURCE = Ending Date of Carrier Code (Active = NULL).';

-- air_oai_dims.airport_history
comment on column air_oai_dims.airport_history.airport_oai_seq_id is 'AIRPORT_SEQ_ID = An identification number assigned by US DOT to identify a unique airport at a given point of time.  Airport attributes, such as airport name or coordinates, may change over time.';
comment on column air_oai_dims.airport_history.airport_oai_id is 'AIRPORT_ID = An identification number assigned by US DOT to identify a unique airport.  Use this field for airport analysis across a range of years because an airport can change its airport code and airport codes can be reused.';
comment on column air_oai_dims.airport_history.airport_oai_code is 'AIRPORT = A three character alpha-numeric code issued by the U.S. Department of Transportation which is the official designation of the airport.  The airport code is not always unique to a specific airport because airport codes can change or can be reused.';
comment on column air_oai_dims.airport_history.airport_display_name is 'DISPLAY_AIRPORT_NAME = Airport Name.';
comment on column air_oai_dims.airport_history.city_full_display_name is 'DISPLAY_AIRPORT_CITY_NAME_FULL = Airport City Name with either U.S. State or Country.';
comment on column air_oai_dims.airport_history.airport_world_area_oai_id is 'AIRPORT_WAC = World Area Code for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.country_name is 'AIRPORT_COUNTRY_NAME = Country Name for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.country_iso_code is 'AIRPORT_COUNTRY_CODE_ISO = Two-character ISO Country Code for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.subdivision_name is 'AIRPORT_STATE_NAME = State Name for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.subdivision_iso_code is 'AIRPORT_STATE_CODE = State Abbreviation for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.subdivision_fips_code is 'AIRPORT_STATE_FIPS = FIPS (Federal Information Processing Standard) State Code for the Physical Location of the Airport.';
comment on column air_oai_dims.airport_history.market_city_oai_id is 'CITY_MARKET_ID = An identification number assigned by US DOT to identify a city market.  Use this field to consolidate airports serving the same city market.';
comment on column air_oai_dims.airport_history.market_city_full_display_name is 'DISPLAY_CITY_MARKET_NAME_FULL = City Market Name with either U.S. State or Country';
comment on column air_oai_dims.airport_history.market_city_world_area_oai_id is 'CITY_MARKET_WAC = World Area Code for the City Market';
comment on column air_oai_dims.airport_history.latitude_decimal_nbr is 'LATITUDE = Latitude';
comment on column air_oai_dims.airport_history.longitude_decimal_nbr is 'LONGITUDE = Longitude';
comment on column air_oai_dims.airport_history.effective_from_date is 'AIRPORT_START_DATE = Start Date of Airport Attributes';
comment on column air_oai_dims.airport_history.effective_thru_date is 'AIRPORT_THRU_DATE = End Date of Airport Attributes (Active = NULL)';
comment on column air_oai_dims.airport_history.airport_closed_ind is 'AIRPORT_IS_CLOSED = Indicates if the airport is closed (1 = Yes).  If yes, the airport is closed is on the AirportEndDate.';
comment on column air_oai_dims.airport_history.airport_latest_ind is 'AIRPORT_IS_LATEST = Indicates if this row contains the latest attributes for the Airport (1 = Yes)';

-- 12. create presentation layer views
-- drop view if exists airlines_pg.aircraft_types_v:
create or replace view airlines_pg.aircraft_types_v as
SELECT aircraft_type_oai_nbr
	 , aircraft_group_oai_nbr
	 , aircraft_oai_type
	 , manufacturer_name
	 , aircraft_type_long_name
	 , aircraft_type_brief_name
	 , aircraft_type_from_date
	 , aircraft_type_thru_date
FROM air_oai_dims.aircraft_types;

-- drop view if exists airlines_pg.airport_history_v;
create or replace view airlines_pg.airport_history_v as
SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date
	, airport_closed_ind, airport_latest_ind, airport_oai_seq_id, airport_oai_id, airport_display_name
	, city_full_display_name
	, airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key
	, utc_local_time_variation, time_zone_name
	, market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name
	, market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_name
	, latitude_decimal_nbr, longitude_decimal_nbr
FROM air_oai_dims.airport_history;

-- drop view if exists airlines_pg.airport_current_v;
create or replace view airlines_pg.airport_current_v as
SELECT -- airport_history_id, airport_history_key,
      airport_oai_code -- , effective_from_date, effective_thru_date
	, airport_closed_ind
	-- , airport_latest_ind, airport_oai_seq_id
	, airport_oai_id, airport_display_name
	, city_full_display_name
	, airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key
	, utc_local_time_variation, time_zone_name
	, market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name
	, market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_name
	, latitude_decimal_nbr, longitude_decimal_nbr
FROM air_oai_dims.airport_history
where airport_latest_ind = 1;

-- drop view if exists airlines_pg.world_areas_v:
create or replace view airlines_pg.world_areas_v as
SELECT world_area_oai_seq_id, world_area_key
	, world_area_oai_id, effective_from_date, effective_thru_date, world_area_latest_ind
	, world_area_name, world_region_name
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_short_name, country_type_descr
	, sovereign_country_name, capital_city_name, world_area_comments_text
FROM air_oai_dims.world_areas;

-- drop view if exists airlines_pg.airline_entity_legacy_groups_v;
create or replace view airlines_pg.airline_entity_legacy_groups_v as
select airline_old_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_legacy_groups;
	 
-- drop view if exists airlines_pg.airline_entity_new_groups_v;
create or replace view airlines_pg.airline_entity_new_groups_v as
select airline_new_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_new_groups;

-- drop view if exists airlines_pg.airline_entities_v:
create or replace view airlines_pg.airline_entities_v as
SELECT airline_entity_id
	, airline_entity_key
	, airline_usdot_id
	, airline_oai_code
	, entity_oai_code
	, airline_name
	, airline_unique_oai_code
	, entity_unique_oai_code
	, airline_unique_name
	, world_area_oai_id
	, world_area_oai_seq_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	, source_from_date
	, source_thru_date
FROM air_oai_dims.airline_entities;

-- drop view if exists airlines_pg.airline_entities_current_v:
create or replace view airlines_pg.airline_entities_current_v as
SELECT --airline_entity_id, airline_entity_key
	 airline_oai_code
	, airline_usdot_id
	, entity_oai_code
	, airline_name
	--, airline_unique_oai_code
	--, entity_unique_oai_code
	--, airline_unique_name
	, world_area_oai_id
	, world_area_oai_seq_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	--, source_from_date
	--, source_thru_date
FROM air_oai_dims.airline_entities
where source_thru_date is null;

-- drop view if exists airlines_pg.airline_geographic_types_v:
create or replace view airlines_pg.airline_geographic_types_v as
SELECT
	geograhic_type_oai_id
	, descr
	, long_descr
from air_oai_dims.airline_geographic_types;

-- drop view if exists airlines_pg.airfare_classes_v:
create or replace view airlines_pg.airfare_classes_v as
SELECT
	airfare_class_code
	, descr
	, long_descr
from air_oai_dims.airfare_classes;

-- drop view if exists airlines_pg.airline_traffic_data_sources_v:
create or replace view airlines_pg.airline_traffic_data_sources_v as
SELECT
	service_class_code
	, descr
	, long_descr
from air_oai_dims.airline_traffic_data_sources;
