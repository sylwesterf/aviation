-- T100 (Market and Segment) (US DoT data) 
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Market (All Carriers)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Segment (All Carriers)	
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EEE&QO_anzr=Nv4%FDPn44vr4%FDf6n6v56vp5%FD%FLS14z%FDHE%FDg4nssvp%FM-%FDNyy%FDPn44vr45&QO_fu146_anzr=Nv4%FDPn44vr45

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month)
-- 1. process Airline Traffic Market data
--  1.1. create air_oai_facts.f41_traffic_t100_market_archive staging table
--  1.2. stage t100_market csv data
-- 	1.3. create a materialized view to transform the data (air_oai_facts.airline_traffic_market_integrate_mv)
-- 	1.4. create final fact table (air_oai_facts.airline_traffic_market) 
--	1.5. pull the data from the materialized view into the fact table
-- 2. process Airline Traffic Segment data
--  2.1. create air_oai_facts.f41_traffic_t100_segment_archive staging table
--  2.2. stage t100_segment csv data
-- 	2.3. create a materialized view to transform the data (air_oai_facts.f41_traffic_t100_segment_load_mv)
--  2.4. create another materialized view (airline_traffic_segment_integrate_mv)
-- 	2.5. create final fact table (air_oai_facts.airline_traffic_segment) 
--	2.6. pull the data from the materialized view into the fact table
-- 3. create dimensional tables by extracting data from the fact tables
--  3.1. air_oai_dims.aircraft_configurations (aircraft_configuration_ref)
-- 	3.2. air_oai_dims.airline_service_classes (service_class_code)
-- 4. add keys and indexes
-- 5. create presentation layer views
----------------------------------------------------

-- 1. process Airline Traffic Market data
-- 1.1. define a table we'll be copying the data to (alternatively use one of the FDW extension)
DROP TABLE if exists air_oai_facts.f41_traffic_t100_market_archive;
CREATE TABLE air_oai_facts.f41_traffic_t100_market_archive
	( passengers_qty 				float4
	, freight_lbr 					float4
	, mail_lbr 						float4
	, distance_smi 					float4
	, airline_unique_oai_code 		varchar(15) -- unique_airline_oai_code
	, airline_usdot_id 				int4
	, airline_unique_name			varchar(125) -- unique_airline_name
	, entity_unique_oai_code 		varchar(15)  -- unique_entity_oai_code
	, operating_region_code 		varchar(5)
	, airline_oai_code 				varchar(5)
	, airline_name					varchar(125)
	, airline_old_group_nbr 		int4
	, airline_new_group_nbr 		int4
	, depart_airport_oai_id 		int4
	, depart_airport_oai_seq_id 	int4
	, depart_city_market_oai_id 	int4
	, depart_airport_oai_code 		varchar(5)
	, depart_city_name 				varchar(75)
	, depart_subdivision_iso_code 	varchar(5)
	, depart_subdivision_fips_code 	varchar(5)
	, depart_subdivision_name 		varchar(75)
	, depart_country_iso_code 		varchar(5)
	, depart_country_name 			varchar(75)
	, depart_world_area_oai_id 		int4
	, arrive_airport_oai_id 		int4
	, arrive_airport_oai_seq_id 	int4
	, arrive_city_market_oai_id 	int4
	, arrive_airport_oai_code 		varchar(5)
	, arrive_city_name 				varchar(75)
	, arrive_subdivision_iso_code 	varchar(5)
	, arrive_subdivision_fips_code 	varchar(5)
	, arrive_subdivision_name 		varchar(75)
	, arrive_country_iso_code 		varchar(5)
	, arrive_country_name 			varchar(75)
	, arrive_world_area_oai_id 		int4
	, year_nbr 						int4
	, quarter_nbr 					int4
	, month_nbr 					int4
	, distance_group_id 			int4
	, service_class_code 			varchar(5)
	, data_source_code 				varchar(5)
	, filler_txt 					varchar(10) 
);

-- 1.2. ingest t100 market csv data
-- 1.2.1. mstr psql version of the data load
-- for x in $(ls /tmp/t100/market/*.csv);
-- do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY  air_oai_facts.f41_traffic_t100_market_archive FROM '$x' CSV HEADER"; done ;
-- 1.2.2. AWS Aurora data load - one file
--TODO SELECT aws_s3.table_import_from_s3()
-- 1.2.3. AWS Aurora data load - mutliple files via manifest
CALL import_data_from_manifest(
    0, 
    'air_oai_facts.f41_traffic_t100_market_archive',  	-- target_table
    'T100/market/manifest_t100_market.csv',      						-- manifest_file
    'src-aviation',                              		-- source_bucket
    'us-west-2',                                 		-- region
    '(FORMAT CSV, DELIMITER '','', HEADER)'      		-- format_options
	,null 													-- max_files_to_import 
);

-- to load data with and withoud 'filler_txt' column -- 10.120.965 rows.
-- ALTER TABLE air_oai_facts.f41_traffic_t100_market_archive DROP COLUMN filler_txt;


-- 1.3. create a materialized view to transform the data
drop materialized view if EXISTS air_oai_facts.airline_traffic_market_integrate_mv;
CREATE MATERIALIZED VIEW air_oai_facts.airline_traffic_market_integrate_mv 
AS
SELECT (f.year_nbr::char(4) || lpad(f.month_nbr::varchar(2),2,'0'))::integer as year_month_nbr
     , f.service_class_code
     , f.airline_usdot_id
     , f.airline_oai_code
     , f.entity_unique_oai_code as entity_oai_code
     , ae.source_from_date as airline_effective_date
     , ae.airline_entity_id
     , ae.airline_entity_key
     , f.airline_name
     , f.airline_unique_name
     , f.depart_airport_oai_code
     , h1.effective_from_date as depart_airport_effective_date
     , h1.airport_history_id as depart_airport_history_id
     , h1.airport_history_key as depart_airport_history_key
     , f.arrive_airport_oai_code
     , h2.effective_from_date as arrive_airport_effective_date
     , h2.airport_history_id as arrive_airport_history_id
     , h2.airport_history_key as arrive_airport_history_key
     , f.data_source_code
     , f.passengers_qty
     , f.freight_lbr
     , f.mail_lbr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_tmst
from air_oai_facts.f41_traffic_t100_market_archive f
--left outer join calendar.year_month_v c on f.year_nbr = c.year_nbr and f.month_nbr = c.month_of_year_nbr
left outer join air_oai_dims.airline_entities ae
  on f.airline_usdot_id = ae.airline_usdot_id
 and f.airline_oai_code = ae.airline_oai_code
 and f.entity_unique_oai_code = ae.entity_unique_oai_code
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= ae.source_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date
   < case when ae.source_thru_date is null then current_date else ae.source_thru_date end
left outer join air_oai_dims.airport_history h1
  on f.depart_airport_oai_id = h1.airport_oai_id
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h1.effective_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < case when h1.effective_thru_date is null then current_date else h1.effective_thru_date end
left outer join air_oai_dims.airport_history h2
  on f.arrive_airport_oai_id = h2.airport_oai_id
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h2.effective_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < case when h2.effective_thru_date is null then current_date else h2.effective_thru_date end
order by f.airline_oai_code, f.depart_airport_oai_code, f.arrive_airport_oai_code;

-- 1.4. create final fact table (air_oai_facts.airline_traffic_market) 
drop table if exists air_oai_facts.airline_traffic_market;
CREATE TABLE air_oai_facts.airline_traffic_market 
( 
	airline_traffic_market_key				char(32)		not null
	, year_month_nbr							integer			not null
	, airline_oai_code 							varchar(3) 		not null
	, airline_effective_date					date			not null
	, airline_entity_id							integer			not null
	, airline_entity_key						char(32)		not null
	, depart_airport_oai_code 					char(3) 		not null
	, depart_airport_effective_date				date			not null
	, depart_airport_history_id					integer 		not null
	, depart_airport_history_key				char(32)		not null
	, arrive_airport_oai_code 					char(3) 		not null
	, arrive_airport_effective_date				date			not null
	, arrive_airport_history_id					integer 		not null
	, arrive_airport_history_key				char(32) 		not null
	, service_class_code 						char(1) 		not null
	, data_source_code							varchar(5)		not null
	, passengers_qty 							integer			not null
	, freight_kgm 								numeric(10,1)	
	, mail_kgm 									numeric(10,1)	not null
	, t100_records_qty 							smallint		not null
	, metadata_key								varchar(32)
	, created_by 								varchar(32)		not null
	, created_tmst 								timestamp(0)	not null
	, updated_by 								varchar(32)
	, updated_tmst 								timestamp(0)
	, constraint airline_traffic_market_pk PRIMARY KEY (airline_traffic_market_key) 
);

-- 1.5. insert values into air_oai_facts.airline_traffic_market from the materialized view air_oai_facts.airline_traffic_market_integrate_mv
INSERT INTO air_oai_facts.airline_traffic_market
( airline_traffic_market_key, year_month_nbr, service_class_code
, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
, data_source_code, passengers_qty, freight_kgm, mail_kgm, t100_records_qty
, created_by, created_tmst)
SELECT md5(year_month_nbr::char(6)
    ||'|'||service_class_code
    ||'|'||airline_entity_key
    ||'|'||depart_airport_history_key
    ||'|'||arrive_airport_history_key
    ) as airline_traffic_market_key2
	 , year_month_nbr
	 , service_class_code
	 , max(airline_oai_code) as airline_oai_code
	 , max(airline_effective_date) as airline_effective_date
	 , max(airline_entity_id) as airline_entity_id
	 , airline_entity_key
	 , max(depart_airport_oai_code) as depart_airport_oai_code
	 , max(depart_airport_effective_date) as depart_airport_effective_date
	 , max(depart_airport_history_id) as depart_airport_history_id
	 , depart_airport_history_key
	 , max(arrive_airport_oai_code) as arrive_airport_oai_code
	 , max(arrive_airport_effective_date) as arrive_airport_effective_date
	 , max(arrive_airport_history_id) as arrive_airport_history_id
	 , arrive_airport_history_key
	 , max(data_source_code) as data_source_code
	 , sum(passengers_qty) as passengers_qty
	 , (sum(freight_lbr)*0.45359237)::numeric(10,1) as freight_kgm
	 , (sum(mail_lbr)*0.45359237)::numeric(10,1) as mail_kgm
	 , count(*) as t100_records_qty
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_tmst
FROM air_oai_facts.airline_traffic_market_integrate_mv
WHERE year_month_nbr is not null -- NOT NULL conditions exclude ~400 rows of market data
and service_class_code is not null 
and airline_entity_key is not null 
and depart_airport_history_key is not null 
and arrive_airport_history_key is not null
--and year_month_nbr between 201001 and 202012 -- 200001 and 200912 -- 199601 and 199912 -- 199101 and 199512
--and year_month_nbr::char(6) like '1990%'
GROUP BY year_month_nbr
     , service_class_code
	 , airline_entity_key --, airline_oai_code, airline_effective_date
	 , depart_airport_history_key --, depart_airport_oai_code, depart_airport_effective_date
	 , arrive_airport_history_key -- , arrive_airport_oai_code, arrive_airport_effective_date
	 ;

-- 2. process Airline Traffic Segment data
-- 2.1. define a table we'll be copying the data to (alternatively use one of the FDW extension)
DROP TABLE IF EXISTS air_oai_facts.f41_traffic_t100_segment_archive;
CREATE TABLE air_oai_facts.f41_traffic_t100_segment_archive
( 
	scheduled_departures_qty	 			float4
	, performed_departures_qty	 			float4
	, payload_lbr 							float4
	, available_seat_qty 					float4
	, passengers_qty 						float4
	, freight_lbr 							float4
	, mail_lbr 								float4
	, distance_smi 							float4
	, ramp_to_ramp_min 						float4
	, air_time_min 							float4
	, airline_unique_oai_code 				varchar(10)
	, airline_usdot_id 						int4
	, airline_unique_name 					varchar(125)
	, entity_unique_oai_code 				varchar(15)
	, operating_region_code 				varchar(25)
	, airline_oai_code 						varchar(5)
	, airline_name 							varchar(125)
	, airline_old_group_nbr					int4
	, airline_new_group_nbr 				int4
	, depart_airport_oai_id 				int4
	, depart_airport_oai_seq_id 			int4
	, depart_market_city_oai_id 			int4
	, depart_airport_oai_code 				varchar(3)
	, depart_city_name 						varchar(75)
	, depart_state_cd 						varchar(5)
	, depart_state_fips_cd 					varchar(5)
	, depart_state_nm 						varchar(75)
	, depart_country_iso_code 				varchar(10)
	, depart_country_name 					varchar(75)
	, depart_world_area_oai_id 				int4
	, arrive_airport_oai_id 				int4
	, arrive_airport_oai_seq_id 			int4
	, arrive_market_city_oai_id 			int4
	, arrive_airport_oai_code 				varchar(5)
	, arrive_city_name 						varchar(75)
	, arrive_subdivision_iso_code 			varchar(5)
	, arrive_subdivision_fips_code 			varchar(5)
	, arrive_subdivision_name 				varchar(75)
	, arrive_country_iso_code 				varchar(10)
	, arrive_country_name 					varchar(75)
	, arrive_world_area_oai_id 				int4
	, aircraft_group_oai_nbr				int4 -- 
	, aircraft_type_oai_nbr 				int4 -- 
	, aircraft_configuration_id 			int4
	, year_nbr 								int4
	, quarter_nbr 							int4
	, month_nbr 							int4
	, distance_group_id 					int4
	, service_class_code 					char(1)
	, data_source_code 						varchar(5)
	, filler_txt 							varchar(10)
);

-- 2.2. stage t100 segment csv data
-- 1.2.1. mstr psql version of the data load
-- for x in $(ls /tmp/t100/segment/*.csv);
-- do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY  air_oai_facts.f41_traffic_t100_segment_archive FROM '$x' CSV HEADER"; done ;
-- 1.2.2. AWS Aurora data load - one file
--TODO SELECT aws_s3.table_import_from_s3()
-- 1.2.3. AWS Aurora data load - mutliple files via manifest
--TODO 
CALL import_data_from_manifest(
    0, 
    'air_oai_facts.f41_traffic_t100_segment_archive',  	-- target_table
    'T100/segment/manifest_t100_segment.csv',      						-- manifest_file
    'src-aviation',                              		-- source_bucket
    'us-west-2',                                 		-- region
    '(FORMAT CSV, DELIMITER '','', HEADER)'      		-- format_options
	,100													-- max_files_to_import 
);

-- to load data with and withoud 'filler_txt' column -- 13.512.137 rows.
-- ALTER TABLE air_oai_facts.f41_traffic_t100_segment_archive DROP COLUMN filler_txt;

-- 	2.3. create a materialized view to transform the data (air_oai_facts.f41_traffic_t100_segment_load_mv)
drop materialized view air_oai_facts.f41_traffic_t100_segment_load_mv;
create materialized view air_oai_facts.f41_traffic_t100_segment_load_mv as
SELECT scheduled_departures_qty
	, performed_departures_qty
	, payload_lbr
	, available_seat_qty
	, passengers_qty
	, freight_lbr
	, mail_lbr
	, distance_smi
	, ramp_to_ramp_min
	, air_time_min
	, airline_unique_oai_code
	-- , airline_usdot_id //repeated
	, case when airline_oai_code = '5G' and airline_usdot_id is null then 21181
	  when airline_oai_code = '0OQ' and airline_usdot_id is null then 21287
	  when airline_oai_code = 'AQ' and airline_usdot_id is null then 19678
	  when airline_oai_code = 'KH' and airline_usdot_id = 19678 then 21634
	  when airline_oai_code = 'K8' and airline_usdot_id is null then 20310
	  when airline_oai_code = 'XP' and airline_usdot_id is null then 20207
	  when airline_oai_code = '2HQ' is not null and airline_usdot_id is null then 21712
	  else airline_usdot_id end::integer as airline_usdot_id
	, airline_unique_name
	-- , entity_unique_oai_code //repeated
	, case when airline_oai_code = '5G' and airline_usdot_id is null then '71032'
	  when airline_oai_code = '0OQ' and airline_usdot_id is null then '71056'
	  when airline_oai_code = 'AQ' and (airline_usdot_id is null or airline_usdot_id = 19678)
        and (depart_country_iso_code in ('US','CA') and arrive_country_iso_code in ('US','CA')) then '05045'
	  when airline_oai_code = 'AQ' and (airline_usdot_id is null or airline_usdot_id = 19678)
	    and (depart_country_iso_code != 'US' or arrive_country_iso_code != 'US') then '15045'
	  when airline_oai_code = 'K8' and airline_usdot_id is null
	    and (depart_country_iso_code != 'US' or arrive_country_iso_code != 'US') then '16076'
	  when airline_oai_code = 'K8' and airline_usdot_id is null
	    and (depart_country_iso_code = 'US' and arrive_country_iso_code = 'US') then '06076'
	  when airline_oai_code = 'XP' and airline_usdot_id is null
	    and (depart_country_iso_code != 'US' or arrive_country_iso_code != 'US') then '16144'
	  when airline_oai_code = 'XP' and airline_usdot_id is null
	    and (depart_country_iso_code = 'US' and arrive_country_iso_code = 'US') then '06144'
	  when airline_oai_code = '2HQ' is not null and airline_usdot_id is null
	    and depart_country_iso_code = 'US' and arrive_country_iso_code = 'US' then '01200'
	  when airline_oai_code = '2HQ' is not null and airline_usdot_id is null
	    and (depart_country_iso_code != 'US' or arrive_country_iso_code != 'US') then '11047'
	 else entity_unique_oai_code end::varchar(15) as entity_unique_oai_code
	, operating_region_code
	--, airline_oai_code   //repeated
	, case when airline_oai_code = '39Q' and airline_usdot_id = 21894 then 'AN'
	  when airline_oai_code = '3GQ' and airline_usdot_id = 21869 then '36Q'
	  when airline_oai_code = 'A0' and airline_usdot_id = 20234 and entity_unique_oai_code = '9486F' then '8R' --changed 
	  else airline_oai_code end::varchar(5) as airline_oai_code
	, airline_name
	, airline_old_group_nbr
	, airline_new_group_nbr
	, depart_airport_oai_id
	, depart_airport_oai_seq_id
	, depart_market_city_oai_id
	, depart_airport_oai_code
	, depart_city_name
	, depart_state_cd
	, depart_state_fips_cd
	, depart_state_nm
	, depart_country_iso_code
	, depart_country_name
	, depart_world_area_oai_id
	, arrive_airport_oai_id
	, arrive_airport_oai_seq_id
	, arrive_market_city_oai_id
	, arrive_airport_oai_code
	, arrive_city_name
	, arrive_subdivision_iso_code
	, arrive_subdivision_fips_code
	, arrive_subdivision_name
	, arrive_country_iso_code
	, arrive_country_name
	, arrive_world_area_oai_id
	, aircraft_group_oai_nbr
	, aircraft_type_oai_nbr
	, aircraft_configuration_id
	, year_nbr
	, quarter_nbr
	, month_nbr
	, distance_group_id
	, service_class_code
	, data_source_code
	--, filler_txt
FROM air_oai_facts.f41_traffic_t100_segment_archive;
--limit 1000;

-- 2.4. create another materialized view (airline_traffic_segment_integrate_mv)
drop materialized view air_oai_facts.airline_traffic_segment_integrate_mv;
CREATE materialized view air_oai_facts.airline_traffic_segment_integrate_mv as
SELECT (f.year_nbr::char(4) || lpad(f.month_nbr::varchar(2),2,'0'))::integer as year_month_nbr
     , f.service_class_code
     , f.airline_usdot_id
     , f.airline_oai_code
     , f.entity_unique_oai_code as entity_oai_code
     , ae.source_from_date as airline_effective_date
     , ae.airline_entity_id
     , ae.airline_entity_key
     , f.airline_name
     , f.airline_unique_name
     , f.depart_airport_oai_code
     , h1.effective_from_date as depart_airport_effective_date
     , h1.airport_history_id as depart_airport_history_id
     , h1.airport_history_key as depart_airport_history_key
     , f.arrive_airport_oai_code
     , h2.effective_from_date as arrive_airport_effective_date
     , h2.airport_history_id as arrive_airport_history_id
     , h2.airport_history_key as arrive_airport_history_key
     , f.aircraft_type_oai_nbr
	 , case when f.aircraft_configuration_id = 0 then 'N/A'
	        when f.aircraft_configuration_id = 1 then 'PAX'
	        when f.aircraft_configuration_id = 2 then 'FRT'
	        when f.aircraft_configuration_id = 3 then 'CMB'
	        when f.aircraft_configuration_id = 4 then 'SEA'
	        when f.aircraft_configuration_id = 9 then 'EXP'
	        else 'UNK' end::char(3) as aircraft_configuration_ref
     , f.data_source_code
     , f.passengers_qty
     , f.freight_lbr
     , f.mail_lbr
     , f.available_seat_qty
     , f.scheduled_departures_qty
     , f.performed_departures_qty
     , f.ramp_to_ramp_min
     , f.air_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_tmst
from air_oai_facts.f41_traffic_t100_segment_archive f
-- left outer join calendar.year_month_v c on f.year_nbr = c.year_nbr and f.month_nbr = c.month_of_year_nbr
left outer join air_oai_dims.airline_entities ae
  on f.airline_usdot_id = ae.airline_usdot_id
 and f.airline_oai_code = ae.airline_oai_code
 and f.entity_unique_oai_code = ae.entity_unique_oai_code
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= ae.source_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < case when ae.source_thru_date is null then current_date else ae.source_thru_date end
left outer join air_oai_dims.airport_history h1
  on f.depart_airport_oai_id = h1.airport_oai_id
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h1.effective_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < case when h1.effective_thru_date is null then current_date else h1.effective_thru_date end
left outer join air_oai_dims.airport_history h2
  on f.arrive_airport_oai_id = h2.airport_oai_id
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h2.effective_from_date
 and (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < case when h2.effective_thru_date is null then current_date else h2.effective_thru_date end
order by f.airline_oai_code, f.depart_airport_oai_code, f.arrive_airport_oai_code;

-- 2.5. create final fact table (air_oai_facts.airline_traffic_segment) 
drop table if exists air_oai_facts.airline_traffic_segment;
CREATE TABLE air_oai_facts.airline_traffic_segment 
( 
	airline_traffic_segment_key				char(32)		not null
	, year_month_nbr							integer			not null
	, service_class_code 						char(1) 		not null	
	, airline_oai_code 							varchar(3) 		not null
	, airline_effective_date					date			not null
	, airline_entity_id							integer			not null
	, airline_entity_key						char(32)		not null
	, depart_airport_oai_code 					char(3) 		not null
	, depart_airport_effective_date				date			not null
	, depart_airport_history_id					integer 		not null
	, depart_airport_history_key				char(32)		not null
	, arrive_airport_oai_code 					char(3) 		not null
	, arrive_airport_effective_date				date			not null
	, arrive_airport_history_id					integer 		not null
	, arrive_airport_history_key				char(32) 		not null
	, aircraft_type_oai_nbr						integer			not null
	, aircraft_configuration_ref				char(3)			not null
	, data_source_code							varchar(5)		not null
	, scheduled_departures_qty					integer			not null
	, performed_departures_qty					integer			not null
	, available_seat_qty						integer			not null
	, passengers_qty 							integer			not null
	, freight_kgm 								numeric(10,1)	not null -- originally lbr, convert to kgm
	, mail_kgm 									numeric(10,1)	not null -- originally lbr, convert to kgm
	, ramp_to_ramp_min							integer			not null
	, air_time_min								integer			not null
	, t100_records_qty							smallint		not null
	, metadata_key								varchar(32)
	, created_by 								varchar(32)		not null
	, created_tmst 								timestamp(0)	not null
	, updated_by 								varchar(32)
	, updated_tmst 								timestamp(0)
	, constraint airline_traffic_segment_pk PRIMARY KEY (airline_traffic_segment_key) 
);

-- 2.6. pull the data from the materialized view into the fact table
INSERT INTO air_oai_facts.airline_traffic_segment
( airline_traffic_segment_key, year_month_nbr, service_class_code
, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
, aircraft_type_oai_nbr, aircraft_configuration_ref, data_source_code, scheduled_departures_qty, performed_departures_qty
, available_seat_qty, passengers_qty, freight_kgm, mail_kgm, ramp_to_ramp_min, air_time_min, t100_records_qty
, created_by, created_tmst)
SELECT md5(year_month_nbr::char(6)
    ||'|'||service_class_code
    ||'|'||airline_entity_key
    ||'|'||depart_airport_history_key
    ||'|'||arrive_airport_history_key
    ||'|'||lpad(aircraft_type_oai_nbr::varchar(3),3,'0')
    ||'|'||aircraft_configuration_ref::char(3)
    ) as airline_traffic_segment_key
	 , year_month_nbr
	 , service_class_code
	 , max(airline_oai_code) as airline_oai_code
	 , max(airline_effective_date) as airline_effective_date
	 , max(airline_entity_id) as airline_entity_id
	 , airline_entity_key
	 , max(depart_airport_oai_code) as depart_airport_oai_code
	 , max(depart_airport_effective_date) as depart_airport_effective_date
	 , max(depart_airport_history_id) as depart_airport_history_id
	 , depart_airport_history_key
	 , max(arrive_airport_oai_code) as arrive_airport_oai_code
	 , max(arrive_airport_effective_date) as arrive_airport_effective_date
	 , max(arrive_airport_history_id) as arrive_airport_history_id
	 , arrive_airport_history_key
	 , aircraft_type_oai_nbr
	 , aircraft_configuration_ref
	 , max(data_source_code) as data_source_code
	 , sum(scheduled_departures_qty) as scheduled_departures_qty
	 , sum(performed_departures_qty) as performed_departures_qty
	 , sum(available_seat_qty) as available_seat_qty
	 , sum(passengers_qty) as passengers_qty
	 , (sum(freight_lbr)*0.45359237)::numeric(10,1) as freight_kgm
	 , (sum(mail_lbr)*0.45359237)::numeric(10,1) as mail_kgm
	 , sum(ramp_to_ramp_min) as ramp_to_ramp_min
	 , sum(air_time_min) as air_time_min
	 , count(*) as t100_records_qty
	 , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_tmst
FROM air_oai_facts.airline_traffic_segment_integrate_mv
WHERE year_month_nbr is not null -- NOT NULL conditions exclude ~700 rows of segment data
and service_class_code is not null 
and airline_entity_key is not null 
and depart_airport_history_key is not null 
and arrive_airport_history_key is not null
and aircraft_type_oai_nbr is not null 
and aircraft_configuration_ref is not null
--and year_month_nbr between 199101 and 199512
--and year_month_nbr::char(6) like '1990%'
GROUP BY year_month_nbr, service_class_code
	 , airline_entity_key --, airline_oai_code, airline_effective_date
	 , depart_airport_history_key --, depart_airport_oai_code, depart_airport_effective_date
	 , arrive_airport_history_key -- , arrive_airport_oai_code, arrive_airport_effective_date
     , aircraft_type_oai_nbr, aircraft_configuration_ref; 


-- 3. create dimensional tables by extracting data from the fact tables
-- 3.1. air_oai_dims.aircraft_configurations (aircraft_configuration_ref)
drop table if exists air_oai_dims.aircraft_configurations;
create table air_oai_dims.aircraft_configurations as
select f.aircraft_configuration_ref
     , max(case f.aircraft_configuration_ref 
			when 'CMB' then 'Combination Freight and Passenger, Main Deck'
            when 'FRT' then 'Freight Only, Main Deck'
            when 'PAX' then 'Passenger Only, Main Deck'
            when 'SEA' then 'Seaplane'
            else null end::varchar(255)) as aircraft_configuration_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_segment f
group by 1 order by 1;

-- 3.2. air_oai_dims.airline_service_classes (service_class_code)
drop table if exists air_oai_dims.airline_service_classes;
create table air_oai_dims.airline_service_classes as
select f.service_class_code
     , max(case when f.service_class_code in ('F','G') then 1 else 0 end::smallint) as scheduled_ind
     , max(case when f.service_class_code in ('L','P') then 1 else 0 end::smallint) as chartered_ind
     , max(case f.service_class_code 
			when 'F' then 'Scheduled Passenger / Cargo Service'
            when 'G' then 'Scheduled CAll Cargo Service'
            when 'L' then 'Non-Scheduled Civilian Passenger / Cargo Service'
            when 'P' then 'Non-Scheduled Civilian All Cargo Service'
            else null end::varchar(255)) as service_class_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_market f
group by 1 order by 1;

-- 4. add keys and indexes
-- dimension tables' primary keys
alter table air_oai_dims.aircraft_configurations 
add constraint aircraft_configurations_pk primary key (aircraft_configuration_ref);

alter table air_oai_dims.airline_service_classes
add constraint airline_service_classes_pk primary key (service_class_code);

-- foreign keys
-- air_oai_facts.airline_traffic_market
alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_service_fk 
foreign key (service_class_code) references air_oai_dims.airline_service_classes (service_class_code);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_airline_id_fk
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_depart_airport_id_fk
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_arrive_airport_key_fk
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_traffic_segment
alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_service_fk 
foreign key (service_class_code) references air_oai_dims.airline_service_classes (service_class_code);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_aircraft_configuration_fk 
foreign key (aircraft_configuration_ref) references air_oai_dims.aircraft_configurations (aircraft_configuration_ref);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_aircraft_type_fk 
foreign key (aircraft_type_oai_nbr) references air_oai_dims.aircraft_types (aircraft_type_oai_nbr);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_arrive_airport_key_fk 
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- 8. create presentation layer views
-- drop view if exists aviation.aircraft_configurations_v;
create or replace view air_oai_dims.aircraft_configurations_v as
SELECT aircraft_configuration_ref
	 , aircraft_configuration_descr
FROM air_oai_dims.aircraft_configurations;

-- drop view if exists airlines_pg.airline_service_classes_v;
create or replace view airlines_pg.airline_service_classes_v as
SELECT service_class_code
	, scheduled_ind
	, chartered_ind
	, service_class_descr
FROM air_oai_dims.airline_service_classes;

-- drop view if exists airlines_pg.airline_traffic_market_v;
create or replace view airlines_pg.airline_traffic_market_v as
SELECT airline_traffic_market_key, year_month_nbr
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, service_class_code, data_source_code
	, passengers_qty, freight_kgm, mail_kgm
	--, t100_records_qty
FROM air_oai_facts.airline_traffic_market;

-- drop view if exists airlines_pg.airline_traffic_segment_v;
create or replace view airlines_pg.airline_traffic_segment_v as
SELECT airline_traffic_segment_key, year_month_nbr, service_class_code
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, aircraft_type_oai_nbr, aircraft_configuration_ref
	, data_source_code
	, scheduled_departures_qty, performed_departures_qty
	, available_seat_qty, passengers_qty, freight_kgm, mail_kgm
	, ramp_to_ramp_min, air_time_min
	--, t100_records_qty
FROM air_oai_facts.airline_traffic_segment;
