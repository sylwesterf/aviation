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
	, airline_unique_oai_code 		varchar(15)
	, airline_usdot_id 				integer
	, airline_unique_name			varchar(125)
	, entity_unique_oai_code 		varchar(15)
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
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1
GZIP
REGION 'us-west-2';

-- 1.3. create a materialized view to transform the data
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.airline_traffic_market_integrate_mv;
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
from air_oai_facts.f41_traffic_t100_market_archive f
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
< case when h2.effective_thru_date is null then current_date else h2.effective_thru_date end;

-- 1.4. create final fact table (air_oai_facts.airline_traffic_market)
DROP TABLE IF EXISTS air_oai_facts.airline_traffic_market;
CREATE TABLE air_oai_facts.airline_traffic_market
(
	  airline_traffic_market_key			char(32)		not null
	, year_month_nbr						integer			not null
	, airline_oai_code 						varchar(3) 		not null
	, airline_effective_date				date			not null
	, airline_entity_id						integer			not null
	, airline_entity_key					char(32)		not null
	, depart_airport_oai_code 				char(3) 		not null
	, depart_airport_effective_date			date			not null
	, depart_airport_history_id				integer 		not null
	, depart_airport_history_key			char(32)		not null
	, arrive_airport_oai_code 				char(3) 		not null
	, arrive_airport_effective_date			date			not null
	, arrive_airport_history_id				integer 		not null
	, arrive_airport_history_key			char(32) 		not null
	, service_class_code 					char(1) 		not null
	, data_source_code						varchar(5)		not null
	, passengers_qty 						integer			not null
	, freight_kgm 							numeric(10,1)
	, mail_kgm 								numeric(10,1)	not null
	, t100_records_qty 						smallint		not null
	, metadata_key							varchar(32)
	, created_by 							varchar(32)		not null
	, created_tmst 							timestamp		not null
	, updated_by 							varchar(32)
	, updated_tmst 							timestamp
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
    ) as airline_traffic_market_key
	 , year_month_nbr
	 , service_class_code
	 , max(airline_oai_code)                            as airline_oai_code
	 , max(airline_effective_date)                      as airline_effective_date
	 , max(airline_entity_id)                           as airline_entity_id
	 , airline_entity_key
	 , max(depart_airport_oai_code)                     as depart_airport_oai_code
	 , max(depart_airport_effective_date)              as depart_airport_effective_date
	 , max(depart_airport_history_id)                  as depart_airport_history_id
	 , depart_airport_history_key
	 , max(arrive_airport_oai_code)                    as arrive_airport_oai_code
	 , max(arrive_airport_effective_date)             as arrive_airport_effective_date
	 , max(arrive_airport_history_id)                 as arrive_airport_history_id
	 , arrive_airport_history_key
	 , max(data_source_code)                           as data_source_code
	 , coalesce(sum(passengers_qty), 0)                as passengers_qty
	 , (sum(freight_lbr)*0.45359237)::numeric(10,1)    as freight_kgm
	 , coalesce((sum(mail_lbr)*0.45359237)::numeric(10,1), 0) as mail_kgm
	 , count(*)                                         as t100_records_qty
     , current_user::varchar(32)                       as created_by
     , current_timestamp::timestamp                    as created_tmst
FROM air_oai_facts.airline_traffic_market_integrate_mv
WHERE year_month_nbr is not null
and service_class_code is not null
and airline_entity_key is not null
and depart_airport_history_key is not null
and arrive_airport_history_key is not null
GROUP BY year_month_nbr
     , service_class_code
	 , airline_entity_key
	 , depart_airport_history_key
	 , arrive_airport_history_key
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
	, aircraft_group_oai_nbr				integer
	, aircraft_type_oai_nbr 				integer
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
-- 2.2. stage t100 segment csv data (Redshift COPY from S3)
COPY air_oai_facts.f41_traffic_t100_segment_archive
FROM 's3://src-aviation/T100/segment/CSV/'
IAM_ROLE 'arn:aws:iam::<account-id>:role/<your-redshift-role>'
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1
GZIP
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
	, case when airline_oai_code = '5G' and airline_usdot_id is null then 21181
	  when airline_oai_code = '0OQ' and airline_usdot_id is null then 21287
	  when airline_oai_code = 'AQ' and airline_usdot_id is null then 19678
	  when airline_oai_code = 'KH' and airline_usdot_id = 19678 then 21634
	  when airline_oai_code = 'K8' and airline_usdot_id is null then 20310
	  when airline_oai_code = 'XP' and airline_usdot_id is null then 20207
	  when airline_oai_code = '2HQ' and airline_usdot_id is null then 21712
	  else airline_usdot_id end::integer as airline_usdot_id
	, airline_unique_name
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
	  when airline_oai_code = '2HQ' and airline_usdot_id is null
	    and depart_country_iso_code = 'US' and arrive_country_iso_code = 'US' then '01200'
	  when airline_oai_code = '2HQ' and airline_usdot_id is null
	    and (depart_country_iso_code != 'US' or arrive_country_iso_code != 'US') then '11047'
	 else entity_unique_oai_code end::varchar(15) as entity_unique_oai_code
	, operating_region_code
	, case when airline_oai_code = '39Q' and airline_usdot_id = 21894 then 'AN'
	  when airline_oai_code = '3GQ' and airline_usdot_id = 21869 then '36Q'
	  when airline_oai_code = 'A0' and airline_usdot_id = 20234 and entity_unique_oai_code = '9486F' then '8R'
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
FROM air_oai_facts.f41_traffic_t100_segment_archive;

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
FROM air_oai_facts.f41_traffic_t100_segment_archive f
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

-- 2.5. create final fact table (air_oai_facts.airline_traffic_segment) 
DROP TABLE IF EXISTS air_oai_facts.airline_traffic_segment;
CREATE TABLE air_oai_facts.airline_traffic_segment
(
      airline_traffic_segment_key           char(32)        NOT NULL
    , year_month_nbr                        integer         NOT NULL
    , service_class_code                    char(1)         NOT NULL
    , airline_oai_code                      varchar(3)      NOT NULL
    , airline_effective_date                date            NOT NULL
    , airline_entity_id                     integer         NOT NULL
    , airline_entity_key                    char(32)        NOT NULL
    , depart_airport_oai_code               char(3)         NOT NULL
    , depart_airport_effective_date         date            NOT NULL
    , depart_airport_history_id             integer         NOT NULL
    , depart_airport_history_key            char(32)        NOT NULL
    , arrive_airport_oai_code               char(3)         NOT NULL
    , arrive_airport_effective_date         date            NOT NULL
    , arrive_airport_history_id             integer         NOT NULL
    , arrive_airport_history_key            char(32)        NOT NULL
    , aircraft_type_oai_nbr                 integer         NOT NULL
    , aircraft_configuration_ref            char(3)         NOT NULL
    , data_source_code                      varchar(5)      NOT NULL
    , scheduled_departures_qty              integer         NOT NULL
    , performed_departures_qty              integer         NOT NULL
    , available_seat_qty                    integer         NOT NULL
    , passengers_qty                        integer         NOT NULL
    , freight_kgm                           numeric(10,1)   NOT NULL
    , mail_kgm                              numeric(10,1)   NOT NULL
    , ramp_to_ramp_min                      integer         NOT NULL
    , air_time_min                          integer         NOT NULL
    , t100_records_qty                      smallint        NOT NULL
    , metadata_key                          varchar(32)
    , created_by                            varchar(32)     NOT NULL
    , created_tmst                          timestamp       NOT NULL
    , updated_by                            varchar(32)
    , updated_tmst                          timestamp
    , CONSTRAINT airline_traffic_segment_pk PRIMARY KEY (airline_traffic_segment_key)
);

-- 2.6. pull the data from the materialized view into the fact table
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
     , max(airline_oai_code)                            AS airline_oai_code
     , max(airline_effective_date)                      AS airline_effective_date
     , max(airline_entity_id)                           AS airline_entity_id
     , airline_entity_key
     , max(depart_airport_oai_code)                     AS depart_airport_oai_code
     , max(depart_airport_effective_date)              AS depart_airport_effective_date
     , max(depart_airport_history_id)                  AS depart_airport_history_id
     , depart_airport_history_key
     , max(arrive_airport_oai_code)                    AS arrive_airport_oai_code
     , max(arrive_airport_effective_date)             AS arrive_airport_effective_date
     , max(arrive_airport_history_id)                 AS arrive_airport_history_id
     , arrive_airport_history_key
     , aircraft_type_oai_nbr
     , aircraft_configuration_ref
     , max(data_source_code)                           AS data_source_code
     , coalesce(sum(scheduled_departures_qty), 0)      AS scheduled_departures_qty
     , coalesce(sum(performed_departures_qty), 0)      AS performed_departures_qty
     , coalesce(sum(available_seat_qty), 0)            AS available_seat_qty
     , coalesce(sum(passengers_qty), 0)                AS passengers_qty
     , coalesce((sum(freight_lbr)*0.45359237)::numeric(10,1), 0) AS freight_kgm
     , coalesce((sum(mail_lbr)*0.45359237)::numeric(10,1), 0)    AS mail_kgm
     , coalesce(sum(ramp_to_ramp_min), 0)              AS ramp_to_ramp_min
     , coalesce(sum(air_time_min), 0)                  AS air_time_min
     , count(*)                                         AS t100_records_qty
     , current_user::varchar(32)                       AS created_by
     , current_timestamp::timestamp                    AS created_tmst
FROM air_oai_facts.airline_traffic_segment_integrate_mv
WHERE year_month_nbr IS NOT NULL
AND service_class_code IS NOT NULL
AND airline_entity_key IS NOT NULL
AND depart_airport_history_key IS NOT NULL
AND arrive_airport_history_key IS NOT NULL
AND aircraft_type_oai_nbr IS NOT NULL
AND aircraft_configuration_ref IS NOT NULL
GROUP BY year_month_nbr, service_class_code
     , airline_entity_key
     , depart_airport_history_key
     , arrive_airport_history_key
     , aircraft_type_oai_nbr, aircraft_configuration_ref;

-- 3. create dimensional tables by extracting data from the fact tables
-- 3.1. air_oai_dims.aircraft_configurations
DROP TABLE IF EXISTS air_oai_dims.aircraft_configurations;
CREATE TABLE air_oai_dims.aircraft_configurations
(
    aircraft_configuration_ref  VARCHAR(255)  NOT NULL
  , aircraft_configuration_descr VARCHAR(255)
  , created_by                  VARCHAR(32)
  , created_ts                  TIMESTAMP
  , updated_by                  CHAR(32)
  , updated_tmst                TIMESTAMP
)
DISTSTYLE EVEN;

INSERT INTO air_oai_dims.aircraft_configurations
SELECT f.aircraft_configuration_ref
     , MAX(CASE f.aircraft_configuration_ref
                WHEN 'CMB' THEN 'Combination Freight and Passenger, Main Deck'
                WHEN 'FRT' THEN 'Freight Only, Main Deck'
                WHEN 'PAX' THEN 'Passenger Only, Main Deck'
                WHEN 'SEA' THEN 'Seaplane'
                ELSE NULL
           END::VARCHAR(255))          AS aircraft_configuration_descr
     , CURRENT_USER::VARCHAR(32)       AS created_by
     , CURRENT_TIMESTAMP::TIMESTAMP    AS created_ts
     , NULL::CHAR(32)                  AS updated_by
     , NULL::TIMESTAMP                 AS updated_tmst
FROM air_oai_facts.airline_traffic_segment f
GROUP BY 1;


-- 3.2. air_oai_dims.airline_service_classes (service_class_code)
DROP TABLE IF EXISTS air_oai_dims.airline_service_classes;
CREATE TABLE air_oai_dims.airline_service_classes
(
    service_class_code    VARCHAR(255)  NOT NULL
  , scheduled_ind         SMALLINT
  , chartered_ind         SMALLINT
  , service_class_descr   VARCHAR(255)
  , created_by            VARCHAR(32)
  , created_ts            TIMESTAMP
  , updated_by            CHAR(32)
  , updated_tmst          TIMESTAMP
)
DISTSTYLE EVEN;

INSERT INTO air_oai_dims.airline_service_classes
SELECT f.service_class_code
     , MAX(CASE WHEN f.service_class_code IN ('F','G') THEN 1 ELSE 0 END::SMALLINT)  AS scheduled_ind
     , MAX(CASE WHEN f.service_class_code IN ('L','P') THEN 1 ELSE 0 END::SMALLINT)  AS chartered_ind
     , MAX(CASE f.service_class_code
                WHEN 'F' THEN 'Scheduled Passenger / Cargo Service'
                WHEN 'G' THEN 'Scheduled Call Cargo Service'
                WHEN 'L' THEN 'Non-Scheduled Civilian Passenger / Cargo Service'
                WHEN 'P' THEN 'Non-Scheduled Civilian All Cargo Service'
                ELSE NULL
           END::VARCHAR(255))              AS service_class_descr
     , CURRENT_USER::VARCHAR(32)           AS created_by
     , CURRENT_TIMESTAMP::TIMESTAMP        AS created_ts
     , NULL::CHAR(32)                      AS updated_by
     , NULL::TIMESTAMP                     AS updated_tmst
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
--aircraft_configurations_v
--drop view if exists airlines_rs.aircraft_configurations_v;
CREATE OR REPLACE VIEW airlines_rs.aircraft_configurations_v AS
SELECT aircraft_configuration_ref
     , aircraft_configuration_descr
FROM air_oai_dims.aircraft_configurations;

-- airline_service_classes_v
-- drop view if exists airlines_rs.airline_service_classes_v;
CREATE OR REPLACE VIEW airlines_rs.airline_service_classes_v AS
SELECT service_class_code
     , scheduled_ind
     , chartered_ind
     , service_class_descr
FROM air_oai_dims.airline_service_classes;

-- airline_traffic_market_v
-- drop view if exists airlines_rs.airline_traffic_market_v;
CREATE OR REPLACE VIEW airlines_rs.airline_traffic_market_v AS
SELECT airline_traffic_market_key
     , year_month_nbr
     , airline_oai_code
     , airline_effective_date
     , airline_entity_id
     , airline_entity_key
     , depart_airport_oai_code
     , depart_airport_effective_date
     , depart_airport_history_id
     , depart_airport_history_key
     , arrive_airport_oai_code
     , arrive_airport_effective_date
     , arrive_airport_history_id
     , arrive_airport_history_key
     , service_class_code
     , data_source_code
     , passengers_qty
     , freight_kgm
     , mail_kgm
     -- , t100_records_qty
FROM air_oai_facts.airline_traffic_market;

-- airline_traffic_segment_v
-- drop view if exists airlines_rs.airline_traffic_segment_v;
CREATE OR REPLACE VIEW airlines_rs.airline_traffic_segment_v AS
SELECT airline_traffic_segment_key
     , year_month_nbr
     , service_class_code
     , airline_oai_code
     , airline_effective_date
     , airline_entity_id
     , airline_entity_key
     , depart_airport_oai_code
     , depart_airport_effective_date
     , depart_airport_history_id
     , depart_airport_history_key
     , arrive_airport_oai_code
     , arrive_airport_effective_date
     , arrive_airport_history_id
     , arrive_airport_history_key
     , aircraft_type_oai_nbr
     , aircraft_configuration_ref
     , data_source_code
     , scheduled_departures_qty
     , performed_departures_qty
     , available_seat_qty
     , passengers_qty
     , freight_kgm
     , mail_kgm
     , ramp_to_ramp_min
     , air_time_min
     -- , t100_records_qty
FROM air_oai_facts.airline_traffic_segment;