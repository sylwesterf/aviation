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
DROP TABLE IF EXISTS air_oai_facts.f41_traffic_t100_market_archive;
CREATE TABLE air_oai_facts.f41_traffic_t100_market_archive
	( passengers_qty 				real
	, freight_lbr 					real
	, mail_lbr 						real
	, distance_smi 					real
	, airline_unique_oai_code 		varchar(15) -- unique_airline_oai_code
	, airline_usdot_id 				integer
	, airline_unique_name			varchar(125) -- unique_airline_name
	, entity_unique_oai_code 		varchar(15)  -- unique_entity_oai_code
	, operating_region_code 		varchar(5)
	, airline_oai_code 				varchar(5)
	, airline_name					varchar(125)
	, airline_old_group_nbr 		integer
	, airline_new_group_nbr 		integer
	, depart_airport_oai_id 		integer
	, depart_airport_oai_seq_id 	integer
	, depart_city_market_oai_id 	integer
	, depart_airport_oai_code 		varchar(5)
	, depart_city_name 				varchar(75)
	, depart_subdivision_iso_code 	varchar(5)
	, depart_subdivision_fips_code 	varchar(5)
	, depart_subdivision_name 		varchar(75)
	, depart_country_iso_code 		varchar(5)
	, depart_country_name 			varchar(75)
	, depart_world_area_oai_id 		integer
	, arrive_airport_oai_id 		integer
	, arrive_airport_oai_seq_id 	integer
	, arrive_city_market_oai_id 	integer
	, arrive_airport_oai_code 		varchar(5)
	, arrive_city_name 				varchar(75)
	, arrive_subdivision_iso_code 	varchar(5)
	, arrive_subdivision_fips_code 	varchar(5)
	, arrive_subdivision_name 		varchar(75)
	, arrive_country_iso_code 		varchar(5)
	, arrive_country_name 			varchar(75)
	, arrive_world_area_oai_id 		integer
	, year_nbr 						integer
	, quarter_nbr 					integer
	, month_nbr 					integer
	, distance_group_id 			integer
	, service_class_code 			varchar(5)
	, data_source_code 				varchar(5)
	--, filler_txt 					varchar(10) 
);

-- 1.2. ingest t100 market csv data
-- single file:
--COPY air_oai_facts.f41_traffic_t100_market_archive
--FROM 's3://src-aviation/T100/market/CSV/T100_MARKET_ALL_CARRIER_ALL_2025.csv.gz' 
--IAM_ROLE default
--CSV GZIP
--IGNOREHEADER 1 
--REGION 'us-west-2';

-- multiple files 
COPY air_oai_facts.f41_traffic_t100_market_archive
FROM 's3://src-aviation/T100/market/CSV/' 
IAM_ROLE default
CSV GZIP
IGNOREHEADER 1 
REGION 'us-west-2';
 
-- 1.3. create a materialized view to transform the data
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.airline_traffic_market_integrate_mv;
CREATE MATERIALIZED VIEW air_oai_facts.airline_traffic_market_integrate_mv
AS
SELECT (f.year_nbr::char(4) || lpad(f.month_nbr::varchar(2),2,'0'))::integer AS year_month_nbr
     , f.service_class_code
     , f.airline_usdot_id
     , f.airline_oai_code
     , f.entity_unique_oai_code AS entity_oai_code
     , ae.source_from_date AS airline_effective_date
     , ae.airline_entity_id
     , ae.airline_entity_key
     , f.airline_name
     , f.airline_unique_name
     , f.depart_airport_oai_code
     , h1.effective_from_date AS depart_airport_effective_date
     , h1.airport_history_id AS depart_airport_history_id
     , h1.airport_history_key AS depart_airport_history_key
     , f.arrive_airport_oai_code
     , h2.effective_from_date AS arrive_airport_effective_date
     , h2.airport_history_id AS arrive_airport_history_id
     , h2.airport_history_key AS arrive_airport_history_key
     , f.data_source_code
     , f.passengers_qty
     , f.freight_lbr
     , f.mail_lbr
     , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_tmst
FROM air_oai_facts.f41_traffic_t100_market_archive f
--left outer join calendar.year_month_v c on f.year_nbr = c.year_nbr and f.month_nbr = c.month_of_year_nbr
LEFT OUTER JOIN air_oai_dims.airline_entities ae
  ON f.airline_usdot_id = ae.airline_usdot_id
 AND f.airline_oai_code = ae.airline_oai_code
 AND f.entity_unique_oai_code = ae.entity_unique_oai_code
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= ae.source_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date
   < CASE WHEN ae.source_thru_date IS NULL THEN current_date ELSE ae.source_thru_date END
LEFT OUTER JOIN air_oai_dims.airport_history h1
  ON f.depart_airport_oai_id = h1.airport_oai_id
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h1.effective_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < CASE WHEN h1.effective_thru_date IS NULL THEN current_date ELSE h1.effective_thru_date END
LEFT OUTER JOIN air_oai_dims.airport_history h2
  ON f.arrive_airport_oai_id = h2.airport_oai_id
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h2.effective_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < CASE WHEN h2.effective_thru_date IS NULL THEN current_date ELSE h2.effective_thru_date END;

-- 1.4. create final fact table (air_oai_facts.airline_traffic_market) 
DROP TABLE IF EXISTS air_oai_facts.airline_traffic_market;
CREATE TABLE air_oai_facts.airline_traffic_market 
( 
	airline_traffic_market_key				char(32)		NOT NULL
	, year_month_nbr						integer			NOT NULL
	, airline_oai_code 						varchar(3) 		NOT NULL
	, airline_effective_date				date			NOT NULL
	, airline_entity_id						integer			NOT NULL
	, airline_entity_key					char(32)		NOT NULL
	, depart_airport_oai_code 				char(3) 		NOT NULL
	, depart_airport_effective_date			date			NOT NULL
	, depart_airport_history_id				integer 		NOT NULL
	, depart_airport_history_key			char(32)		NOT NULL
	, arrive_airport_oai_code 				char(3) 		NOT NULL
	, arrive_airport_effective_date			date			NOT NULL
	, arrive_airport_history_id				integer 		NOT NULL
	, arrive_airport_history_key			char(32) 		NOT NULL
	, service_class_code 					char(1) 		NOT NULL
	, data_source_code						varchar(5)		NOT NULL
	, passengers_qty 						integer			NOT NULL
	, freight_kgm 							numeric(10,1)	
	, mail_kgm 								numeric(10,1)	NOT NULL
	, t100_records_qty 						smallint		NOT NULL
	, metadata_key							varchar(32)
	, created_by 							varchar(32)		NOT NULL
	, created_tmst 							timestamp(0)	NOT NULL
	, updated_by 							varchar(32)
	, updated_tmst 							timestamp(0)
	, CONSTRAINT airline_traffic_market_pk PRIMARY KEY (airline_traffic_market_key) 
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
    ) AS airline_traffic_market_key2
	 , year_month_nbr
	 , service_class_code
	 , max(airline_oai_code) AS airline_oai_code
	 , max(airline_effective_date) AS airline_effective_date
	 , max(airline_entity_id) AS airline_entity_id
	 , airline_entity_key
	 , max(depart_airport_oai_code) AS depart_airport_oai_code
	 , max(depart_airport_effective_date) AS depart_airport_effective_date
	 , max(depart_airport_history_id) AS depart_airport_history_id
	 , depart_airport_history_key
	 , max(arrive_airport_oai_code) AS arrive_airport_oai_code
	 , max(arrive_airport_effective_date) AS arrive_airport_effective_date
	 , max(arrive_airport_history_id) AS arrive_airport_history_id
	 , arrive_airport_history_key
	 , max(data_source_code) AS data_source_code
	 , sum(passengers_qty) AS passengers_qty
	 , (sum(freight_lbr)*0.45359237)::numeric(10,1) AS freight_kgm
	 , (sum(mail_lbr)*0.45359237)::numeric(10,1) AS mail_kgm
	 , count(*) AS t100_records_qty
     , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_tmst
FROM air_oai_facts.airline_traffic_market_integrate_mv
WHERE year_month_nbr IS NOT NULL -- NOT NULL conditions exclude ~400 rows of market data
AND service_class_code IS NOT NULL 
AND airline_entity_key IS NOT NULL 
AND depart_airport_history_key IS NOT NULL 
AND arrive_airport_history_key IS NOT NULL
--AND year_month_nbr BETWEEN 201001 AND 202012 -- 200001 and 200912 -- 199601 and 199912 -- 199101 and 199512
--AND year_month_nbr::char(6) LIKE '1990%'
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
	scheduled_departures_qty	 			real
	, performed_departures_qty	 			real
	, payload_lbr 							real
	, available_seat_qty 					real
	, passengers_qty 						real
	, freight_lbr 							real
	, mail_lbr 								real
	, distance_smi 							real
	, ramp_to_ramp_min 						real
	, air_time_min 							real
	, airline_unique_oai_code 				varchar(10)
	, airline_usdot_id 						integer
	, airline_unique_name 					varchar(125)
	, entity_unique_oai_code 				varchar(15)
	, operating_region_code 				varchar(25)
	, airline_oai_code 						varchar(5)
	, airline_name 							varchar(125)
	, airline_old_group_nbr					integer
	, airline_new_group_nbr 				integer
	, depart_airport_oai_id 				integer
	, depart_airport_oai_seq_id 			integer
	, depart_market_city_oai_id 			integer
	, depart_airport_oai_code 				varchar(3)
	, depart_city_name 						varchar(75)
	, depart_state_cd 						varchar(5)
	, depart_state_fips_cd 					varchar(5)
	, depart_state_nm 						varchar(75)
	, depart_country_iso_code 				varchar(10)
	, depart_country_name 					varchar(75)
	, depart_world_area_oai_id 				integer
	, arrive_airport_oai_id 				integer
	, arrive_airport_oai_seq_id 			integer
	, arrive_market_city_oai_id 			integer
	, arrive_airport_oai_code 				varchar(5)
	, arrive_city_name 						varchar(75)
	, arrive_subdivision_iso_code 			varchar(5)
	, arrive_subdivision_fips_code 			varchar(5)
	, arrive_subdivision_name 				varchar(75)
	, arrive_country_iso_code 				varchar(10)
	, arrive_country_name 					varchar(75)
	, arrive_world_area_oai_id 				integer
	, aircraft_group_oai_nbr				integer -- 
	, aircraft_type_oai_nbr 				integer -- 
	, aircraft_configuration_id 			integer
	, year_nbr 								integer
	, quarter_nbr 							integer
	, month_nbr 							integer
	, distance_group_id 					integer
	, service_class_code 					char(1)
	, data_source_code 						varchar(5)
	--, filler_txt 							varchar(10)
);

-- 2.2. stage t100 segment csv data
-- single file:
--COPY air_oai_facts.f41_traffic_t100_segment_archive
--FROM 's3://src-aviation/T100/segment/CSV/T100_SEGMENT_ALL_CARRIER_ALL_2024.csv.gz'
--IAM_ROLE default
--CSV GZIP
--IGNOREHEADER 1
--REGION 'us-west-2';

-- multiple files
COPY air_oai_facts.f41_traffic_t100_segment_archive
FROM 's3://src-aviation/T100/segment/CSV'
IAM_ROLE default
CSV GZIP
IGNOREHEADER 1
REGION 'us-west-2';

-- to load data with and withoud 'filler_txt' column -- 13.512.137 rows.
-- ALTER TABLE air_oai_facts.f41_traffic_t100_segment_archive DROP COLUMN filler_txt;

-- 	2.3. create a materialized view to transform the data (air_oai_facts.f41_traffic_t100_segment_load_mv)
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.f41_traffic_t100_segment_load_mv;
CREATE MATERIALIZED VIEW air_oai_facts.f41_traffic_t100_segment_load_mv AS
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
	, CASE WHEN airline_oai_code = '5G' AND airline_usdot_id IS NULL THEN 21181
	  WHEN airline_oai_code = '0OQ' AND airline_usdot_id IS NULL THEN 21287
	  WHEN airline_oai_code = 'AQ' AND airline_usdot_id IS NULL THEN 19678
	  WHEN airline_oai_code = 'KH' AND airline_usdot_id = 19678 THEN 21634
	  WHEN airline_oai_code = 'K8' AND airline_usdot_id IS NULL THEN 20310
	  WHEN airline_oai_code = 'XP' AND airline_usdot_id IS NULL THEN 20207
	  WHEN airline_oai_code = '2HQ' IS NOT NULL AND airline_usdot_id IS NULL THEN 21712
	  ELSE airline_usdot_id END::integer AS airline_usdot_id
	, airline_unique_name
	-- , entity_unique_oai_code //repeated
	, CASE WHEN airline_oai_code = '5G' AND airline_usdot_id IS NULL THEN '71032'
	  WHEN airline_oai_code = '0OQ' AND airline_usdot_id IS NULL THEN '71056'
	  WHEN airline_oai_code = 'AQ' AND (airline_usdot_id IS NULL OR airline_usdot_id = 19678)
        AND (depart_country_iso_code IN ('US','CA') AND arrive_country_iso_code IN ('US','CA')) THEN '05045'
	  WHEN airline_oai_code = 'AQ' AND (airline_usdot_id IS NULL OR airline_usdot_id = 19678)
	    AND (depart_country_iso_code != 'US' OR arrive_country_iso_code != 'US') THEN '15045'
	  WHEN airline_oai_code = 'K8' AND airline_usdot_id IS NULL
	    AND (depart_country_iso_code != 'US' OR arrive_country_iso_code != 'US') THEN '16076'
	  WHEN airline_oai_code = 'K8' AND airline_usdot_id IS NULL
	    AND (depart_country_iso_code = 'US' AND arrive_country_iso_code = 'US') THEN '06076'
	  WHEN airline_oai_code = 'XP' AND airline_usdot_id IS NULL
	    AND (depart_country_iso_code != 'US' OR arrive_country_iso_code != 'US') THEN '16144'
	  WHEN airline_oai_code = 'XP' AND airline_usdot_id IS NULL
	    AND (depart_country_iso_code = 'US' AND arrive_country_iso_code = 'US') THEN '06144'
	  WHEN airline_oai_code = '2HQ' IS NOT NULL AND airline_usdot_id IS NULL
	    AND depart_country_iso_code = 'US' AND arrive_country_iso_code = 'US' THEN '01200'
	  WHEN airline_oai_code = '2HQ' IS NOT NULL AND airline_usdot_id IS NULL
	    AND (depart_country_iso_code != 'US' OR arrive_country_iso_code != 'US') THEN '11047'
	 ELSE entity_unique_oai_code END::varchar(15) AS entity_unique_oai_code
	, operating_region_code
	--, airline_oai_code   //repeated
	, CASE WHEN airline_oai_code = '39Q' AND airline_usdot_id = 21894 THEN 'AN'
	  WHEN airline_oai_code = '3GQ' AND airline_usdot_id = 21869 THEN '36Q'
	  WHEN airline_oai_code = 'A0' AND airline_usdot_id = 20234 AND entity_unique_oai_code = '9486F' THEN '8R' --changed 
	  ELSE airline_oai_code END::varchar(5) AS airline_oai_code
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
--LIMIT 1000;

-- 2.4. create another materialized view (airline_traffic_segment_integrate_mv)
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.airline_traffic_segment_integrate_mv;
CREATE MATERIALIZED VIEW air_oai_facts.airline_traffic_segment_integrate_mv AS
SELECT (f.year_nbr::char(4) || lpad(f.month_nbr::varchar(2),2,'0'))::integer AS year_month_nbr
     , f.service_class_code
     , f.airline_usdot_id
     , f.airline_oai_code
     , f.entity_unique_oai_code AS entity_oai_code
     , ae.source_from_date AS airline_effective_date
     , ae.airline_entity_id
     , ae.airline_entity_key
     , f.airline_name
     , f.airline_unique_name
     , f.depart_airport_oai_code
     , h1.effective_from_date AS depart_airport_effective_date
     , h1.airport_history_id AS depart_airport_history_id
     , h1.airport_history_key AS depart_airport_history_key
     , f.arrive_airport_oai_code
     , h2.effective_from_date AS arrive_airport_effective_date
     , h2.airport_history_id AS arrive_airport_history_id
     , h2.airport_history_key AS arrive_airport_history_key
     , f.aircraft_type_oai_nbr
	 , CASE WHEN f.aircraft_configuration_id = 0 THEN 'N/A'
	        WHEN f.aircraft_configuration_id = 1 THEN 'PAX'
	        WHEN f.aircraft_configuration_id = 2 THEN 'FRT'
	        WHEN f.aircraft_configuration_id = 3 THEN 'CMB'
	        WHEN f.aircraft_configuration_id = 4 THEN 'SEA'
	        WHEN f.aircraft_configuration_id = 9 THEN 'EXP'
	        ELSE 'UNK' END::char(3) AS aircraft_configuration_ref
     , f.data_source_code
     , f.passengers_qty
     , f.freight_lbr
     , f.mail_lbr
     , f.available_seat_qty
     , f.scheduled_departures_qty
     , f.performed_departures_qty
     , f.ramp_to_ramp_min
     , f.air_time_min
     , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_tmst
FROM air_oai_facts.f41_traffic_t100_segment_archive f
-- left outer join calendar.year_month_v c on f.year_nbr = c.year_nbr and f.month_nbr = c.month_of_year_nbr
LEFT OUTER JOIN air_oai_dims.airline_entities ae
  ON f.airline_usdot_id = ae.airline_usdot_id
 AND f.airline_oai_code = ae.airline_oai_code
 AND f.entity_unique_oai_code = ae.entity_unique_oai_code
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= ae.source_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < CASE WHEN ae.source_thru_date IS NULL THEN current_date ELSE ae.source_thru_date END
LEFT OUTER JOIN air_oai_dims.airport_history h1
  ON f.depart_airport_oai_id = h1.airport_oai_id
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h1.effective_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date 
   < CASE WHEN h1.effective_thru_date IS NULL THEN current_date ELSE h1.effective_thru_date END
LEFT OUTER JOIN air_oai_dims.airport_history h2
  ON f.arrive_airport_oai_id = h2.airport_oai_id
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date >= h2.effective_from_date
 AND (f.year_nbr::char(4) ||'-'|| lpad(f.month_nbr::varchar(2),2,'0') || '-01')::date < CASE WHEN h2.effective_thru_date IS NULL THEN current_date ELSE h2.effective_thru_date END;

-- 2.5. create final fact table (air_oai_facts.airline_traffic_segment) 
DROP TABLE IF EXISTS air_oai_facts.airline_traffic_segment;
CREATE TABLE air_oai_facts.airline_traffic_segment 
( 
	airline_traffic_segment_key				char(32)		NOT NULL
	, year_month_nbr						integer			NOT NULL
	, service_class_code 					char(1) 		NOT NULL	
	, airline_oai_code 						varchar(3) 		NOT NULL
	, airline_effective_date				date			NOT NULL
	, airline_entity_id						integer			NOT NULL
	, airline_entity_key					char(32)		NOT NULL
	, depart_airport_oai_code 				char(3) 		NOT NULL
	, depart_airport_effective_date			date			NOT NULL
	, depart_airport_history_id				integer 		NOT NULL
	, depart_airport_history_key			char(32)		NOT NULL
	, arrive_airport_oai_code 				char(3) 		NOT NULL
	, arrive_airport_effective_date			date			NOT NULL
	, arrive_airport_history_id				integer 		NOT NULL
	, arrive_airport_history_key			char(32) 		NOT NULL
	, aircraft_type_oai_nbr					integer			NOT NULL
	, aircraft_configuration_ref			char(3)			NOT NULL
	, data_source_code						varchar(5)		NOT NULL
	, scheduled_departures_qty				integer			NOT NULL
	, performed_departures_qty				integer			NOT NULL
	, available_seat_qty					integer			NOT NULL
	, passengers_qty 						integer			NOT NULL
	, freight_kgm 							numeric(10,1)	NOT NULL -- originally lbr, convert to kgm
	, mail_kgm 								numeric(10,1)	NOT NULL -- originally lbr, convert to kgm
	, ramp_to_ramp_min						integer			NOT NULL
	, air_time_min							integer			NOT NULL
	, t100_records_qty						smallint		NOT NULL
	, metadata_key							varchar(32)
	, created_by 							varchar(32)		NOT NULL
	, created_tmst 							timestamp(0)	NOT NULL
	, updated_by 							varchar(32)
	, updated_tmst 							timestamp(0)
	, CONSTRAINT airline_traffic_segment_pk PRIMARY KEY (airline_traffic_segment_key) 
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
    ) AS airline_traffic_segment_key
	 , year_month_nbr
	 , service_class_code
	 , max(airline_oai_code) AS airline_oai_code
	 , max(airline_effective_date) AS airline_effective_date
	 , max(airline_entity_id) AS airline_entity_id
	 , airline_entity_key
	 , max(depart_airport_oai_code) AS depart_airport_oai_code
	 , max(depart_airport_effective_date) AS depart_airport_effective_date
	 , max(depart_airport_history_id) AS depart_airport_history_id
	 , depart_airport_history_key
	 , max(arrive_airport_oai_code) AS arrive_airport_oai_code
	 , max(arrive_airport_effective_date) AS arrive_airport_effective_date
	 , max(arrive_airport_history_id) AS arrive_airport_history_id
	 , arrive_airport_history_key
	 , aircraft_type_oai_nbr
	 , aircraft_configuration_ref
	 , max(data_source_code) AS data_source_code
	 , sum(scheduled_departures_qty) AS scheduled_departures_qty
	 , sum(performed_departures_qty) AS performed_departures_qty
	 , sum(available_seat_qty) AS available_seat_qty
	 , sum(passengers_qty) AS passengers_qty
	 , (sum(freight_lbr)*0.45359237)::numeric(10,1) AS freight_kgm
	 , (sum(mail_lbr)*0.45359237)::numeric(10,1) AS mail_kgm
	 , sum(ramp_to_ramp_min) AS ramp_to_ramp_min
	 , sum(air_time_min) AS air_time_min
	 , count(*) AS t100_records_qty
	 , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_tmst
FROM air_oai_facts.airline_traffic_segment_integrate_mv
WHERE year_month_nbr IS NOT NULL -- NOT NULL conditions exclude ~700 rows of segment data
AND service_class_code IS NOT NULL 
AND airline_entity_key IS NOT NULL 
AND depart_airport_history_key IS NOT NULL 
AND arrive_airport_history_key IS NOT NULL
AND aircraft_type_oai_nbr IS NOT NULL 
AND aircraft_configuration_ref IS NOT NULL
--AND year_month_nbr BETWEEN 199101 AND 199512
--AND year_month_nbr::char(6) LIKE '1990%'
GROUP BY year_month_nbr, service_class_code
	 , airline_entity_key --, airline_oai_code, airline_effective_date
	 , depart_airport_history_key --, depart_airport_oai_code, depart_airport_effective_date
	 , arrive_airport_history_key -- , arrive_airport_oai_code, arrive_airport_effective_date
     , aircraft_type_oai_nbr, aircraft_configuration_ref; 


-- 3. create dimensional tables by extracting data from the fact tables
-- 3.1. air_oai_dims.aircraft_configurations (aircraft_configuration_ref)
DROP TABLE IF EXISTS air_oai_dims.aircraft_configurations;
CREATE TABLE air_oai_dims.aircraft_configurations AS
SELECT f.aircraft_configuration_ref
     , max(CASE f.aircraft_configuration_ref 
			WHEN 'CMB' THEN 'Combination Freight and Passenger, Main Deck'
            WHEN 'FRT' THEN 'Freight Only, Main Deck'
            WHEN 'PAX' THEN 'Passenger Only, Main Deck'
            WHEN 'SEA' THEN 'Seaplane'
            ELSE NULL END::varchar(255)) AS aircraft_configuration_descr
     , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_ts
     , NULL::char(32) AS updated_by
     , NULL::timestamp(0) AS updated_tmst
FROM air_oai_facts.airline_traffic_segment f
GROUP BY 1;

-- 3.2. air_oai_dims.airline_service_classes (service_class_code)
DROP TABLE IF EXISTS air_oai_dims.airline_service_classes;
CREATE TABLE air_oai_dims.airline_service_classes AS
SELECT f.service_class_code
     , max(CASE WHEN f.service_class_code IN ('F','G') THEN 1 ELSE 0 END::smallint) AS scheduled_ind
     , max(CASE WHEN f.service_class_code IN ('L','P') THEN 1 ELSE 0 END::smallint) AS chartered_ind
     , max(CASE f.service_class_code 
			WHEN 'F' THEN 'Scheduled Passenger / Cargo Service'
            WHEN 'G' THEN 'Scheduled CAll Cargo Service'
            WHEN 'L' THEN 'Non-Scheduled Civilian Passenger / Cargo Service'
            WHEN 'P' THEN 'Non-Scheduled Civilian All Cargo Service'
            ELSE NULL END::varchar(255)) AS service_class_descr
     , current_user::varchar(32) AS created_by
     , current_timestamp::timestamp(0) AS created_ts
     , NULL::char(32) AS updated_by
     , NULL::timestamp(0) AS updated_tmst
FROM air_oai_facts.airline_traffic_market f
GROUP BY 1;

-- 4. add keys and indexes
-- dimension tables' primary keys
ALTER TABLE air_oai_dims.aircraft_configurations 
ADD CONSTRAINT aircraft_configurations_pk PRIMARY KEY (aircraft_configuration_ref);

ALTER TABLE air_oai_dims.airline_service_classes
ADD CONSTRAINT airline_service_classes_pk PRIMARY KEY (service_class_code);

-- foreign keys
-- air_oai_facts.airline_traffic_market
ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_service_fk 
FOREIGN KEY (service_class_code) REFERENCES air_oai_dims.airline_service_classes (service_class_code);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_airline_id_fk
FOREIGN KEY (airline_entity_id) REFERENCES air_oai_dims.airline_entities (airline_entity_id);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_depart_airport_id_fk
FOREIGN KEY (depart_airport_history_id) REFERENCES air_oai_dims.airport_history (airport_history_id);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_arrive_airport_id_fk 
FOREIGN KEY (arrive_airport_history_id) REFERENCES air_oai_dims.airport_history (airport_history_id);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_airline_key_fk 
FOREIGN KEY (airline_entity_key) REFERENCES air_oai_dims.airline_entities (airline_entity_key);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_depart_airport_key_fk 
FOREIGN KEY (depart_airport_history_key) REFERENCES air_oai_dims.airport_history (airport_history_key);

ALTER TABLE air_oai_facts.airline_traffic_market ADD CONSTRAINT airline_traffic_market_arrive_airport_key_fk
FOREIGN KEY (arrive_airport_history_key) REFERENCES air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_traffic_segment
ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_service_fk 
FOREIGN KEY (service_class_code) REFERENCES air_oai_dims.airline_service_classes (service_class_code);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_aircraft_configuration_fk 
FOREIGN KEY (aircraft_configuration_ref) REFERENCES air_oai_dims.aircraft_configurations (aircraft_configuration_ref);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_aircraft_type_fk 
FOREIGN KEY (aircraft_type_oai_nbr) REFERENCES air_oai_dims.aircraft_types (aircraft_type_oai_nbr);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_airline_id_fk 
FOREIGN KEY (airline_entity_id) REFERENCES air_oai_dims.airline_entities (airline_entity_id);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_depart_airport_id_fk 
FOREIGN KEY (depart_airport_history_id) REFERENCES air_oai_dims.airport_history (airport_history_id);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_arrive_airport_id_fk 
FOREIGN KEY (arrive_airport_history_id) REFERENCES air_oai_dims.airport_history (airport_history_id);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_airline_key_fk 
FOREIGN KEY (airline_entity_key) REFERENCES air_oai_dims.airline_entities (airline_entity_key);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_depart_airport_key_fk 
FOREIGN KEY (depart_airport_history_key) REFERENCES air_oai_dims.airport_history (airport_history_key);

ALTER TABLE air_oai_facts.airline_traffic_segment ADD CONSTRAINT airline_traffic_segment_arrive_airport_key_fk 
FOREIGN KEY (arrive_airport_history_key) REFERENCES air_oai_dims.airport_history (airport_history_key);

-- 58. create presentation layer views
--drop view if exists airlines_pg.aircraft_configurations_v;
CREATE OR REPLACE VIEW airlines_pg.aircraft_configurations_v AS
SELECT aircraft_configuration_ref
	 , aircraft_configuration_descr
FROM air_oai_dims.aircraft_configurations;

-- drop view if exists airlines_pg.airline_service_classes_v;
CREATE OR REPLACE VIEW airlines_pg.airline_service_classes_v AS
SELECT service_class_code
	, scheduled_ind
	, chartered_ind
	, service_class_descr
FROM air_oai_dims.airline_service_classes;

-- drop view if exists airlines_pg.airline_traffic_market_v;
CREATE OR REPLACE VIEW airlines_pg.airline_traffic_market_v AS
SELECT airline_traffic_market_key, year_month_nbr
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, service_class_code, data_source_code
	, passengers_qty, freight_kgm, mail_kgm
	--, t100_records_qty
FROM air_oai_facts.airline_traffic_market;

-- drop view if exists airlines_pg.airline_traffic_segment_v;
CREATE OR REPLACE VIEW airlines_pg.airline_traffic_segment_v AS
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
