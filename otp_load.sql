-- OTP (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline On-Time Performance Data Database > Reporting Carrier On-Time Performance (1987-present)
-- https://transtats.bts.gov/Tables.asp?QO_VQ=EFD&QO_anzr=Nv4yv0r%FDb0-gvzr%FDcr4s14zn0pr%FDQn6n&QO_fu146_anzr=b0-gvzr

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. create air_oai_facts.airline_flight_performance_fdw table in postgre
-- 2. ingest OTP csv data using copy command 
-- 3. define materialized views to transform the data:
--  3.1. air_oai_facts.airline_flight_performance_mv 
--  3.2. air_oai_facts.airline_flight_performance_integrated_mv (timezone, keys, data types)
-- 4. create fact tables by pulling the data from air_oai_facts.airline_flight_performance_integrated_mv with appropriate conditions:
--  4.1. air_oai_facts.airline_flights_completed (cancelled_ind = 0 AND diverted_ind = 0)
--  4.2. air_oai_facts.airline_flights_cancelled (cancelled_ind = 1)
--  4.3. air_oai_facts.airline_flights_diverted (diverted_ind = 1)
--  4.4. air_oai_facts.airline_flights_diverted_legs (union different number of flight diversions, diverted_ind = 1 AND diverted<1-5>_airport_history_id is not null)
--  4.5. air_oai_facts.airline_flights_scheduled 
--   4.5.1. base data insert (completed flights)
--   4.5.2. update flight status
--   4.5.3. insert cancelled flights
--   4.5.4. insert diverted flights
-- 5. add keys and indexes
-- 6. create presentation layer views
----------------------------------------------------

-- 1. define a table we'll be copying the data to (alternatively use one of the FDW extension)
drop table if exists air_oai_facts.airline_flight_performance_fdw cascade;
CREATE TABLE air_oai_facts.airline_flight_performance_fdw
(
    year_nbr                          SMALLINT NULL,
    quarter_nbr                       SMALLINT NULL,
    month_nbr                         SMALLINT NULL,
    day_of_month                      SMALLINT NULL,
    day_of_week                       SMALLINT NULL,
    flight_date                       DATE NULL,
    airline_unique_oai_code           VARCHAR(10) NULL,
    airline_usdot_id                  INTEGER NULL,
    airline_oai_code                  CHAR(3) NULL,
    tail_nbr                          VARCHAR(7) NULL,
    flight_nbr                        VARCHAR(4) NULL,
    depart_airport_oai_id             INTEGER NULL,
    depart_airport_seq_id             INTEGER NULL,
    depart_city_market_id             INTEGER NULL,
    depart_airport_oai_code           CHAR(3) NULL,
    depart_city_name                  VARCHAR(125) NULL,
    depart_state_iso_code             CHAR(2) NULL,
    depart_state_fips_code            VARCHAR(3) NULL,
    depart_state_name                 VARCHAR(125) NULL,
    depart_world_area_oai_id          SMALLINT NULL,
    arrive_airport_oai_id             INTEGER NULL,
    arrive_airport_seq_oai_id         INTEGER NULL,
    arrive_city_market_id             INTEGER NULL,
    arrive_airport_oai_code           CHAR(3) NULL,
    arrive_city_name                  VARCHAR(125) NULL,
    arrive_state_iso_code             CHAR(2) NULL,
    arrive_state_fips_code            VARCHAR(3) NULL,
    arrive_state_name                 VARCHAR(125) NULL,
    arrive_world_area_oai_id          SMALLINT NULL,
    report_depart_time_lcl            CHAR(4) NULL,
    actual_depart_time_lcl            CHAR(4) NULL,
    depart_delay_min                  FLOAT4 NULL,
    depart_delay_pos_min              FLOAT4 NULL,
    depart_delay_15min_ind            FLOAT4 NULL,
    depart_delay_group_id             SMALLINT NULL,
    depart_time_block                 VARCHAR(10) NULL,
    taxi_out_min                      FLOAT4 NULL,
    wheels_off_time_lcl               CHAR(4) NULL,
    wheels_on_time_lcl                CHAR(4) NULL,
    taxi_in_min                       FLOAT4 NULL,
    report_arrive_time_lcl            CHAR(4) NULL,
    actual_arrive_time_lcl            CHAR(4) NULL,
    arrive_delay_min                  FLOAT4 NULL,
    arrive_delay_pos_min              FLOAT4 NULL,
    arrive_delay_15min_ind            FLOAT4 NULL,
    arrive_delay_group_id             SMALLINT NULL,
    arrive_time_block                 VARCHAR(10) NULL,
    cancelled_ind                     FLOAT4 NULL,
    cancellation_code                 VARCHAR(10) NULL,
    diverted_ind                      FLOAT4 NULL,
    report_elapsed_time_min           FLOAT4 NULL,
    actual_elapsed_time_min           FLOAT4 NULL,
    airborne_time_min                 FLOAT4 NULL,
    flight_count                      FLOAT4 NULL,
    distance_smi                      FLOAT4 NULL,
    distance_group_id                 FLOAT4 NULL,
    airline_delay_min                 FLOAT4 NULL,
    weather_delay_min                 FLOAT4 NULL,
    nas_delay_min                     FLOAT4 NULL,
    security_delay_min                FLOAT4 NULL,
    late_aircraft_delay_min           FLOAT4 NULL,
    first_gate_depart_time            VARCHAR(10) NULL,
    total_ground_time                 VARCHAR(10) NULL,
    longest_ground_time               VARCHAR(10) NULL,
    diverted_airport_landing_count    FLOAT4 NULL,
    diverted_reached_dest_ind         FLOAT4 NULL,
    diverted_actual_elapsed_time_min  FLOAT4 NULL,
    diverted_arrive_delay_min         FLOAT4 NULL,
    diverted_distance_smi             FLOAT4 NULL,
    diverted1_airport_oai_code        CHAR(3) NULL,
    diverted1_airport_oai_id          INTEGER NULL,
    diverted1_airport_seq_oai_id      INTEGER NULL,
    diverted1_wheels_on_time_lcl      CHAR(4) NULL,
    diverted1_total_ground_time_min   FLOAT4 NULL,
    diverted1_longest_ground_time_min FLOAT4 NULL,
    diverted1_wheels_off_time_lcl     CHAR(4) NULL,
    diverted1_tail_nbr                VARCHAR(7) NULL,
    diverted2_airport_oai_code        CHAR(3) NULL,
    diverted2_airport_oai_id          INTEGER NULL,
    diverted2_airport_seq_oai_id      INTEGER NULL,
    diverted2_wheels_on_time_lcl      CHAR(4) NULL,
    diverted2_total_ground_time_min   FLOAT4 NULL,
    diverted2_longest_ground_time_min FLOAT4 NULL,
    diverted2_wheels_off_time_lcl     CHAR(4) NULL,
    diverted2_tail_nbr                VARCHAR(7) NULL,
    diverted3_airport_oai_code        CHAR(3) NULL,
    diverted3_airport_oai_id          INTEGER NULL,
    diverted3_airport_seq_oai_id      INTEGER NULL,
    diverted3_wheels_on_time_lcl      CHAR(4) NULL,
    diverted3_total_ground_time_min   FLOAT4 NULL,
    diverted3_longest_ground_time_min FLOAT4 NULL,
    diverted3_wheels_off_time_lcl     CHAR(4) NULL,
    diverted3_tail_nbr                VARCHAR(7) NULL,
    diverted4_airport_oai_code        CHAR(3) NULL,
    diverted4_airport_oai_id          INTEGER NULL,
    diverted4_airport_seq_oai_id      INTEGER NULL,
    diverted4_wheels_on_time_lcl      CHAR(4) NULL,
    diverted4_total_ground_time_min   FLOAT4 NULL,
    diverted4_longest_ground_time_min FLOAT4 NULL,
    diverted4_wheels_off_time_lcl     CHAR(4) NULL,
    diverted4_tail_nbr                VARCHAR(7) NULL,
    diverted5_airport_oai_code        CHAR(3) NULL,
    diverted5_airport_oai_id          INTEGER NULL,
    diverted5_airport_seq_oai_id      INTEGER NULL,
    diverted5_wheels_on_time_lcl      CHAR(4) NULL,
    diverted5_total_ground_time_min   FLOAT4 NULL,
    diverted5_longest_ground_time_min FLOAT4 NULL,
    diverted5_wheels_off_time_lcl     CHAR(4) NULL,
    diverted5_tail_nbr                VARCHAR(7) NULL,
    filler                            VARCHAR(10) NULL
);

-- 2. copy OTP data into air_oai_facts.airline_flight_performance_fdw
-- 2.1. mstr psql version of the data load
-- for x in $(ls /tmp/otp/*.csv); do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY air_oai_facts.airline_flight_performance_fdw FROM '$x' CSV HEADER"; done;
-- 2.2. AWS Aurora data load - one file
-- SELECT aws_s3.table_import_from_s3('air_oai_facts.airline_flight_performance_fdw', '', '(FORMAT CSV, HEADER true)', aws_commons.create_s3_uri('src-aviation', '/OTP/CSV/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_1987_10.csv.gz', 'us-west-2'));
-- 2.3. AWS Aurora data load - mutliple files via manifest
CALL import_data_from_manifest(
    0, 
    'air_oai_facts.airline_flight_performance_fdw',  	-- target_table
    'OTP/manifest_otp.csv',      						-- manifest_file
    'src-aviation',                              		-- source_bucket
    'us-west-2',                                 		-- region
    '(FORMAT CSV, DELIMITER '','', HEADER)'      		-- format_options
	,3 													-- max_files_to_import 
);

-- 3.1. define materialized view for initial data quality work (removed spaces)
drop materialized view if exists air_oai_facts.airline_flight_performance_mv cascade;
create materialized view air_oai_facts.airline_flight_performance_mv 
as 
select flight_date
	 , airline_oai_code
	 , tail_nbr
	 , flight_nbr
	 , depart_airport_oai_code
	 , arrive_airport_oai_code
	 , report_depart_time_lcl
	 , case when replace(actual_depart_time_lcl,' ','') = '' then null 
	        else actual_depart_time_lcl end::char(4) as actual_depart_time_lcl
	 , depart_delay_min
	 , depart_delay_pos_min
	 , depart_delay_15min_ind
	 , depart_delay_group_id
	 , depart_time_block
	 , taxi_out_min
	 , case when replace(wheels_off_time_lcl,' ','') = '' then null 
	        else wheels_off_time_lcl end::char(4) as wheels_off_time_lcl
	 , case when replace(wheels_on_time_lcl,' ','') = '' then null 
	        else wheels_on_time_lcl end::char(4) as wheels_on_time_lcl
	 , taxi_in_min
	 , report_arrive_time_lcl
	 , case when replace(actual_arrive_time_lcl, ' ','') = '' then null 
	        else actual_arrive_time_lcl end::char(4) as actual_arrive_time_lcl
	 , arrive_delay_min
	 , arrive_delay_pos_min
	 , arrive_delay_15min_ind
	 , arrive_delay_group_id
	 , arrive_time_block
	 , cancelled_ind
	 , cancellation_code
	 , diverted_ind
	 , report_elapsed_time_min
	 , actual_elapsed_time_min
	 , airborne_time_min
	 , flight_count
	 , distance_smi
	 , distance_group_id
	 , airline_delay_min
	 , weather_delay_min
	 , nas_delay_min
	 , security_delay_min
	 , late_aircraft_delay_min
	 , case when replace(first_gate_depart_time, ' ','') = '' then null 
	        else first_gate_depart_time end::char(4) as first_gate_depart_time
	 , total_ground_time
	 , longest_ground_time
	 , diverted_airport_landing_count
	 , diverted_reached_dest_ind
	 , diverted_actual_elapsed_time_min
	 , diverted_arrive_delay_min
	 , diverted_distance_smi
	 , diverted1_airport_oai_code
	 --, diverted1_wheels_on_time_lcl
	 , case when replace(diverted1_wheels_on_time_lcl, ' ','') = '' then null 
	        else diverted1_wheels_on_time_lcl end::char(4) as diverted1_wheels_on_time_lcl
	 , diverted1_total_ground_time_min
	 , diverted1_longest_ground_time_min
	 --, diverted1_wheels_off_time_lcl
	 , case when replace(diverted1_wheels_off_time_lcl, ' ','') = '' then null 
	        else diverted1_wheels_off_time_lcl end::char(4) as diverted1_wheels_off_time_lcl
	 , diverted1_tail_nbr
	 , diverted2_airport_oai_code
	 --, diverted2_wheels_on_time_lcl
	 , case when replace(diverted2_wheels_on_time_lcl, ' ','') = '' then null 
	        else diverted2_wheels_on_time_lcl end::char(4) as diverted2_wheels_on_time_lcl
	 , diverted2_total_ground_time_min
	 , diverted2_longest_ground_time_min
	 --, diverted2_wheels_off_time_lcl
	 , case when replace(diverted2_wheels_off_time_lcl, ' ','') = '' then null 
	        else diverted2_wheels_off_time_lcl end::char(4) as diverted2_wheels_off_time_lcl
	 , diverted2_tail_nbr
	 , diverted3_airport_oai_code
	 --, diverted3_wheels_on_time_lcl
	 , case when replace(diverted3_wheels_on_time_lcl, ' ','') = '' then null 
	        else diverted3_wheels_on_time_lcl end::char(4) as diverted3_wheels_on_time_lcl
	 , diverted3_total_ground_time_min
	 , diverted3_longest_ground_time_min
	 --, diverted3_wheels_off_time_lcl
	 , case when replace(diverted3_wheels_off_time_lcl, ' ','') = '' then null 
	        else diverted3_wheels_off_time_lcl end::char(4) as diverted3_wheels_off_time_lcl
	 , diverted3_tail_nbr
	 , diverted4_airport_oai_code
	 --, diverted4_wheels_on_time_lcl
	 , case when replace(diverted4_wheels_on_time_lcl, ' ','') = '' then null 
	        else diverted4_wheels_on_time_lcl end::char(4) as diverted4_wheels_on_time_lcl
	 , diverted4_total_ground_time_min
	 , diverted4_longest_ground_time_min
	 --, diverted4_wheels_off_time_lcl
	 , case when replace(diverted4_wheels_off_time_lcl, ' ','') = '' then null 
	        else diverted4_wheels_off_time_lcl end::char(4) as diverted4_wheels_off_time_lcl
	 , diverted4_tail_nbr
	 , diverted5_airport_oai_code
	 --, diverted5_wheels_on_time_lcl
	 , case when replace(diverted5_wheels_on_time_lcl, ' ','') = '' then null 
	        else diverted5_wheels_on_time_lcl end::char(4) as diverted5_wheels_on_time_lcl
	 , diverted5_total_ground_time_min
	 , diverted5_longest_ground_time_min
	 --, diverted5_wheels_off_time_lcl
	 , case when replace(diverted5_wheels_off_time_lcl, ' ','') = '' then null 
	        else diverted5_wheels_off_time_lcl end::char(4) as diverted5_wheels_off_time_lcl
	 , diverted5_tail_nbr
from air_oai_facts.airline_flight_performance_fdw; 

-- improve performance on table joins
create index airline_flight_performance_mv_depart_airport_idx on air_oai_facts.airline_flight_performance_mv (depart_airport_oai_code);
create index airline_flight_performance_mv_arrive_airport_idx on air_oai_facts.airline_flight_performance_mv (arrive_airport_oai_code);
create index airline_flight_performance_mv_flight_date_idx on air_oai_facts.airline_flight_performance_mv (flight_date);

-- 3.2. define a "final" materialized view with some data transformations (timezone, data types)
-- we'll load the data into individual fact tables from our materialized view 
drop materialized view if exists air_oai_facts.airline_flight_performance_integrated_mv cascade;
create materialized view air_oai_facts.airline_flight_performance_integrated_mv 
as
select md5(fp.airline_oai_code||'|'||fp.flight_nbr||'|'||fp.flight_date::text||'|'||fp.depart_airport_oai_code)::char(32) as flight_key
     , fp.airline_oai_code||'|'||fp.flight_nbr||'|'||fp.flight_date::text||'|'||fp.depart_airport_oai_code as flight_key_comp
     , fp.flight_date::date								as flight_date
	 , fp.airline_oai_code::varchar(3)					as airline_oai_code
	 , ae.source_from_date								as airline_entity_from_date
	 , ae.airline_entity_id								as airline_entity_id
	 , ae.airline_entity_key							as airline_entity_key
	 , lpad(fp.flight_nbr,4,'0')::char(4)				as flight_nbr
	 , fp.flight_count::smallint						as flight_count
	 , fp.tail_nbr::varchar(10)							as tail_nbr
	 , fp.depart_airport_oai_code::char(3)				as depart_airport_oai_code
	 , a.effective_from_date							as depart_airport_from_date 
	 , a.airport_history_id								as depart_airport_history_id
	 , a.airport_history_key							as depart_airport_history_key
	 , a.time_zone_name									as depart_time_zone_name
	 , fp.arrive_airport_oai_code::char(3)				as arrive_airport_oai_code
	 , b.effective_from_date							as arrive_airport_from_date 
	 , b.airport_history_id								as arrive_airport_history_id
	 , b.airport_history_key							as arrive_airport_history_key
	 , b.time_zone_name									as arrive_time_zone_name
	 , case when cancelled_ind = 1 then 'cancelled' when diverted_ind = 1 then 'diverted' 
	        when fp.airline_delay_min::smallint is not null then 'arrived_delayed'
	        else 'arrived_on_time' end::varchar(25) as flight_status
     , fp.cancelled_ind::smallint						as cancelled_ind
	 , fp.cancellation_code::varchar(25)				as cancellation_code
	 , fp.diverted_ind::smallint						as diverted_ind
	 , fp.distance_smi::smallint						as distance_smi
	 , (fp.distance_smi / 1.1508::float)::smallint		as distance_nmi
	 , (fp.distance_smi * 1.60934::float)::smallint		as distance_kmt
	 , fp.distance_group_id::smallint					as distance_group_id
	 , fp.depart_time_block
	 , fp.arrive_time_block
	 , fp.report_depart_time_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(report_depart_time_lcl::time)::char(8))::timestamp) at time zone a.time_zone_name as report_depart_tmstz_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(report_depart_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			  as report_depart_tmstz_utc
	 , fp.report_arrive_time_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(report_arrive_time_lcl::time)::char(8))::timestamp) at time zone b.time_zone_name as report_arrive_tmstz_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(report_arrive_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			  as report_arrive_tmstz_utc
	 , fp.report_elapsed_time_min -- redundant?
	 , fp.actual_depart_time_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(actual_depart_time_lcl::time)::char(8))::timestamp) at time zone a.time_zone_name as actual_depart_tmstz_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(actual_depart_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			  as actual_depart_tmstz_utc
	 , fp.actual_arrive_time_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(actual_arrive_time_lcl::time)::char(8))::timestamp) at time zone b.time_zone_name as actual_arrive_tmstz_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(actual_arrive_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			  as actual_arrive_tmstz_utc
	 , fp.actual_elapsed_time_min -- redundant?
	 , fp.wheels_off_time_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(wheels_off_time_lcl::time)::char(8))::timestamp) at time zone a.time_zone_name as wheels_off_tmstz_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		   as wheels_off_tmstz_utc
	 , fp.wheels_on_time_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(wheels_on_time_lcl::time)::char(8))::timestamp) at time zone b.time_zone_name as wheels_on_tmstz_lcl
	 , timezone(b.time_zone_name, (flight_date::char(10)||' '||(wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			  as wheels_on_tmstz_utc
	 , fp.airborne_time_min -- redundant?
	 , fp.taxi_out_min::smallint						as taxi_out_min  -- redundant?
	 , fp.taxi_in_min::smallint							as taxi_in_min  -- redundant?
	 , fp.first_gate_depart_time
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(first_gate_depart_time::time)::char(8))::timestamp) at time zone a.time_zone_name as first_gate_depart_tmstz_lcl
	 , timezone(a.time_zone_name, (flight_date::char(10)||' '||(first_gate_depart_time::time)::char(8))::timestamp) at time zone 'UTC' 			  as first_gate_depart_tmstz_utc
	 , (fp.total_ground_time::numeric(3,0))::smallint	as total_ground_time
	 , (fp.longest_ground_time::numeric(3,0))::smallint	as longest_ground_time
	 , fp.airline_delay_min::smallint					as airline_delay_min
	 , fp.weather_delay_min::smallint					as weather_delay_min
	 , fp.nas_delay_min::smallint						as nas_delay_min
	 , fp.security_delay_min::smallint					as security_delay_min
	 , fp.late_aircraft_delay_min::smallint				as late_aircraft_delay_min
	 , fp.diverted_airport_landing_count::smallint		as diverted_airport_landing_count
	 , fp.diverted_reached_dest_ind::smallint			as diverted_reached_dest_ind
	 , fp.diverted_actual_elapsed_time_min::smallint	as diverted_actual_elapsed_time_min
	 , fp.diverted_arrive_delay_min::smallint			as diverted_arrive_delay_min
	 , fp.diverted_distance_smi::integer				as diverted_distance_smi
	 , fp.diverted1_airport_oai_code::char(3)			as diverted1_airport_oai_code
	 , d1.effective_from_date							as diverted1_airport_from_date 
     , d1.airport_history_id							as diverted1_airport_history_id
	 , d1.airport_history_key							as diverted1_airport_history_key
	 , d1.time_zone_name								as diverted1_time_zone_name
	 , fp.diverted2_airport_oai_code::char(3)			as diverted2_airport_oai_code
	 , d2.effective_from_date							as diverted2_airport_from_date 
     , d2.airport_history_id							as diverted2_airport_history_id
	 , d2.airport_history_key							as diverted2_airport_history_key
	 , d2.time_zone_name								as diverted2_time_zone_name
	 , fp.diverted3_airport_oai_code::char(3)			as diverted3_airport_oai_code
	 , d3.effective_from_date							as diverted3_airport_from_date 
     , d3.airport_history_id							as diverted3_airport_history_id
	 , d3.airport_history_key							as diverted3_airport_history_key
	 , d3.time_zone_name								as diverted3_time_zone_name
	 , fp.diverted4_airport_oai_code::char(3)			as diverted4_airport_oai_code
	 , d4.effective_from_date							as diverted4_airport_from_date 
     , d4.airport_history_id							as diverted4_airport_history_id
	 , d4.airport_history_key							as diverted4_airport_history_key
	 , d4.time_zone_name								as diverted4_time_zone_name
	 , fp.diverted5_airport_oai_code::char(3)			as diverted5_airport_oai_code
	 , d5.effective_from_date							as diverted5_airport_from_date 
     , d5.airport_history_id							as diverted5_airport_history_id
	 , d5.airport_history_key							as diverted5_airport_history_key
	 , d5.time_zone_name								as diverted5_time_zone_name
	 , fp.diverted1_tail_nbr::varchar(10)				as diverted1_tail_nbr
	 , fp.diverted2_tail_nbr::varchar(10)				as diverted2_tail_nbr
	 , fp.diverted3_tail_nbr::varchar(10)				as diverted3_tail_nbr
	 , fp.diverted4_tail_nbr::varchar(10)				as diverted4_tail_nbr
	 , fp.diverted5_tail_nbr::varchar(10)				as diverted5_tail_nbr
	 , fp.diverted1_wheels_on_time_lcl
	 , timezone(d1.time_zone_name, (flight_date::char(10)||' '||(diverted1_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone d1.time_zone_name as diverted1_wheels_on_tmstz_lcl
	 , timezone(d1.time_zone_name, (flight_date::char(10)||' '||(diverted1_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 			 as diverted1_wheels_on_tmstz_utc
	 , fp.diverted1_wheels_off_time_lcl
	 , timezone(d1.time_zone_name, (flight_date::char(10)||' '||(diverted1_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone d1.time_zone_name as diverted1_wheels_off_tmstz_lcl
	 , timezone(d1.time_zone_name, (flight_date::char(10)||' '||(diverted1_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		      as diverted1_wheels_off_tmstz_utc
	 , fp.diverted1_total_ground_time_min::smallint		as diverted1_total_ground_time_min
	 , fp.diverted1_longest_ground_time_min::smallint	as diverted1_longest_ground_time_min
	 , fp.diverted2_wheels_on_time_lcl
	 , timezone(d2.time_zone_name, (flight_date::char(10)||' '||(diverted2_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone d2.time_zone_name as diverted2_wheels_on_tmstz_lcl
	 , timezone(d2.time_zone_name, (flight_date::char(10)||' '||(diverted2_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		      as diverted2_wheels_on_tmstz_utc
	 , fp.diverted2_wheels_off_time_lcl
	 , timezone(d2.time_zone_name, (flight_date::char(10)||' '||(diverted2_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone d2.time_zone_name as diverted2_wheels_off_tmstz_lcl
	 , timezone(d2.time_zone_name, (flight_date::char(10)||' '||(diverted2_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		       as diverted2_wheels_off_tmstz_utc
	 , fp.diverted2_total_ground_time_min::smallint		as diverted2_total_ground_time_min
	 , fp.diverted2_longest_ground_time_min::smallint	as diverted2_longest_ground_time_min
	 , fp.diverted3_wheels_on_time_lcl
	 , timezone(d3.time_zone_name, (flight_date::char(10)||' '||(diverted3_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone d3.time_zone_name as diverted3_wheels_on_tmstz_lcl
	 , timezone(d3.time_zone_name, (flight_date::char(10)||' '||(diverted3_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		      as diverted3_wheels_on_tmstz_utc
	 , fp.diverted3_wheels_off_time_lcl
	 , timezone(d3.time_zone_name, (flight_date::char(10)||' '||(diverted3_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone d3.time_zone_name as diverted3_wheels_off_tmstz_lcl
	 , timezone(d3.time_zone_name, (flight_date::char(10)||' '||(diverted3_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		       as diverted3_wheels_off_tmstz_utc
	 , fp.diverted3_total_ground_time_min::smallint		as diverted3_total_ground_time_min
	 , fp.diverted3_longest_ground_time_min::smallint	as diverted3_longest_ground_time_min
	 , fp.diverted4_wheels_on_time_lcl
	 , timezone(d4.time_zone_name, (flight_date::char(10)||' '||(diverted4_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone d4.time_zone_name as diverted4_wheels_on_tmstz_lcl
	 , timezone(d4.time_zone_name, (flight_date::char(10)||' '||(diverted4_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		      as diverted4_wheels_on_tmstz_utc
	 , fp.diverted4_wheels_off_time_lcl
	 , timezone(d4.time_zone_name, (flight_date::char(10)||' '||(diverted4_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone d4.time_zone_name as diverted4_wheels_off_tmstz_lcl
	 , timezone(d4.time_zone_name, (flight_date::char(10)||' '||(diverted4_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		       as diverted4_wheels_off_tmstz_utc
	 , fp.diverted4_total_ground_time_min::smallint		as diverted4_total_ground_time_min
	 , fp.diverted4_longest_ground_time_min::smallint	as diverted4_longest_ground_time_min
	 , fp.diverted5_wheels_on_time_lcl
	 , timezone(d5.time_zone_name, (flight_date::char(10)||' '||(diverted5_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone d5.time_zone_name as diverted5_wheels_on_tmstz_lcl
	 , timezone(d5.time_zone_name, (flight_date::char(10)||' '||(diverted5_wheels_on_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		      as diverted5_wheels_on_tmstz_utc
	 , fp.diverted5_wheels_off_time_lcl
	 , timezone(d5.time_zone_name, (flight_date::char(10)||' '||(diverted5_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone d5.time_zone_name as diverted5_wheels_off_tmstz_lcl
	 , timezone(d5.time_zone_name, (flight_date::char(10)||' '||(diverted5_wheels_off_time_lcl::time)::char(8))::timestamp) at time zone 'UTC' 		       as diverted5_wheels_off_tmstz_utc
	 , fp.diverted5_total_ground_time_min::smallint		as diverted5_total_ground_time_min
	 , fp.diverted5_longest_ground_time_min::smallint	as diverted5_longest_ground_time_min
FROM air_oai_facts.airline_flight_performance_mv fp
left outer join 
(
	select airline_entity_id, airline_entity_key, airline_oai_code, source_from_date, source_thru_date 
	from air_oai_dims.airline_entities 
	where operating_region_code = 'Domestic'
) ae on fp.airline_oai_code = ae.airline_oai_code and fp.flight_date between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) a on fp.depart_airport_oai_code = a.airport_oai_code and fp.flight_date between a.effective_from_date and coalesce(a.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) b on fp.arrive_airport_oai_code = b.airport_oai_code and fp.flight_date between b.effective_from_date and coalesce(b.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) d1 on fp.diverted1_airport_oai_code = d1.airport_oai_code and fp.flight_date between d1.effective_from_date and coalesce(d1.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) d2 on fp.diverted2_airport_oai_code = d2.airport_oai_code and fp.flight_date between d2.effective_from_date and coalesce(d2.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) d3 on fp.diverted3_airport_oai_code = d3.airport_oai_code and fp.flight_date between d3.effective_from_date and coalesce(d3.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) d4 on fp.diverted4_airport_oai_code = d4.airport_oai_code and fp.flight_date between d4.effective_from_date and coalesce(d4.effective_thru_date, current_date)
left outer join 
(
	select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name 
	from air_oai_dims.airport_history
) d5 on fp.diverted5_airport_oai_code = d5.airport_oai_code and fp.flight_date between d5.effective_from_date and coalesce(d5.effective_thru_date, current_date);


-- 4.1. air_oai_facts.airline_flights_completed 
drop table if exists air_oai_facts.airline_flights_completed cascade;
create table air_oai_facts.airline_flights_completed 
as
SELECT flight_key --, flight_key_comp
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code
	 , arrive_airport_from_date
	 , arrive_airport_history_id
	 , arrive_airport_history_key
	 , distance_smi
	 , distance_nmi
	 , distance_kmt
	 , distance_group_id
	 , depart_time_block
	 , arrive_time_block
	 , report_depart_tmstz_lcl
	 , report_depart_tmstz_utc
	 --, report_arrive_tmstz_lcl as report_arrive_tmstz_lcl0
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_lcl + (interval '24 hours')
	        else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
	 --, report_arrive_tmstz_utc as report_arrive_tmstz_utc0
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_utc + (interval '24 hours')
	        else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
	 , report_elapsed_time_min
	 , case when airline_delay_min is not null then 'completed-delayed' 
	        else 'completed-on-time' end::varchar(25) as flight_status
	 , actual_depart_tmstz_lcl
	 , actual_depart_tmstz_utc
	 --, actual_arrive_tmstz_lcl as actual_arrive_tmstz_lcl0
	 , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
	        then actual_arrive_tmstz_lcl + (interval '24 hours')
	        else actual_arrive_tmstz_lcl end as actual_arrive_tmstz_lcl
	 --, actual_arrive_tmstz_utc as actual_arrive_tmstz_utc0
	 , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
	        then actual_arrive_tmstz_utc + (interval '24 hours')
	        else actual_arrive_tmstz_utc end as actual_arrive_tmstz_utc
	 , actual_elapsed_time_min
	 --, actual_arrive_tmstz_utc - actual_depart_tmstz_utc as actual_elapsed_time_min1
	 --, case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
	 --       then actual_arrive_tmstz_utc + (interval '24 hours')
	 --       else actual_arrive_tmstz_utc end - actual_depart_tmstz_utc as actual_elapsed_time_min2
	 , wheels_off_tmstz_lcl
	 , wheels_off_tmstz_utc
	 --, wheels_on_tmstz_lcl as wheels_on_tmstz_lcl0
	 , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc
	        then wheels_on_tmstz_lcl + (interval '24 hours')
	        else wheels_on_tmstz_lcl end as wheels_on_tmstz_lcl
	 --, wheels_on_tmstz_utc as wheels_on_tmstz_utc0
	 , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc
	        then wheels_on_tmstz_utc + (interval '24 hours')
	        else wheels_on_tmstz_utc end as wheels_on_tmstz_utc
	 --, wheels_on_tmstz_utc - wheels_off_tmstz_utc as airborne_time_min1
	 --, case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc
	 --       then wheels_on_tmstz_utc + (interval '24 hours')
	 --       else wheels_on_tmstz_utc end - wheels_off_tmstz_utc as airborne_time_min2
	 , airborne_time_min
	 , taxi_out_min
	 , taxi_in_min
	 , first_gate_depart_tmstz_lcl
	 , first_gate_depart_tmstz_utc
	 , total_ground_time
	 , longest_ground_time
	 , airline_delay_min
	 , weather_delay_min
	 , nas_delay_min
	 , security_delay_min
	 , late_aircraft_delay_min
	 , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where cancelled_ind = 0 and diverted_ind = 0;


-- 4.2. air_oai_facts.airline_flights_cancelled 
drop table if exists air_oai_facts.airline_flights_cancelled cascade;
create table air_oai_facts.airline_flights_cancelled 
as
SELECT flight_key --, flight_key_comp
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code
	 , arrive_airport_from_date
	 , arrive_airport_history_id
	 , arrive_airport_history_key
	 , distance_smi
	 , distance_nmi
	 , distance_kmt
	 , distance_group_id
	 , depart_time_block
	 , arrive_time_block
	 , report_depart_tmstz_lcl
	 , report_depart_tmstz_utc
	 --, report_arrive_tmstz_lcl as report_arrive_tmstz_lcl0
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_lcl + (interval '24 hours')
	        else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
	 --, report_arrive_tmstz_utc as report_arrive_tmstz_utc0
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_utc + (interval '24 hours')
	        else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
	 , report_elapsed_time_min
	 , flight_status
	 , actual_depart_tmstz_lcl
	 , actual_depart_tmstz_utc
	 , wheels_off_tmstz_lcl
	 , wheels_off_tmstz_utc
	 , taxi_out_min
	 , first_gate_depart_tmstz_lcl
	 , first_gate_depart_tmstz_utc
	 , total_ground_time
	 , longest_ground_time
	 , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where cancelled_ind = 1;


-- 4.3. air_oai_facts.airline_flights_diverted
drop table if exists air_oai_facts.airline_flights_diverted cascade;
create table air_oai_facts.airline_flights_diverted 
as
SELECT flight_key --, flight_key_comp
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code
	 , arrive_airport_from_date
	 , arrive_airport_history_id
	 , arrive_airport_history_key
	 , distance_smi
	 , distance_nmi
	 , distance_kmt
	 , distance_group_id
	 , depart_time_block
	 , arrive_time_block
	 , report_depart_tmstz_lcl
	 , report_depart_tmstz_utc
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_lcl + (interval '24 hours')
	        else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_utc + (interval '24 hours')
	        else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
	 , report_elapsed_time_min
	 , flight_status
	 , actual_depart_tmstz_lcl
	 , actual_depart_tmstz_utc
	 , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
	        then actual_arrive_tmstz_lcl + (interval '24 hours')
	        else actual_arrive_tmstz_lcl end as actual_arrive_tmstz_lcl
	 , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
	        then actual_arrive_tmstz_utc + (interval '24 hours')
	        else actual_arrive_tmstz_utc end as actual_arrive_tmstz_utc
	 , actual_elapsed_time_min
	 , wheels_off_tmstz_lcl
	 , wheels_off_tmstz_utc
	 , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc
	        then wheels_on_tmstz_lcl + (interval '24 hours')
	        else wheels_on_tmstz_lcl end as wheels_on_tmstz_lcl
	 , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc
	        then wheels_on_tmstz_utc + (interval '24 hours')
	        else wheels_on_tmstz_utc end as wheels_on_tmstz_utc
	 , airborne_time_min
	 , taxi_out_min
	 , taxi_in_min
	 , first_gate_depart_tmstz_lcl
	 , first_gate_depart_tmstz_utc
	 , total_ground_time
	 , longest_ground_time
	 , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1;


-- 4.4. air_oai_facts.airline_flights_diverted_legs 
drop table if exists air_oai_facts.airline_flights_diverted_legs cascade;
create table air_oai_facts.airline_flights_diverted_legs as
SELECT flight_key --, flight_key_comp
     , 1::smallint as diversion_nbr
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code				as original_arrive_airport_oai_code
	 , arrive_airport_from_date				as original_arrive_airport_from_date
	 , arrive_airport_history_id			as original_arrive_airport_history_id
	 , arrive_airport_history_key			as original_arrive_airport_history_key
     , diverted1_airport_oai_code			as diverted_airport_oai_code
     , diverted1_airport_from_date			as diverted_airport_from_date
     , diverted1_airport_history_id			as diverted_airport_history_id
     , diverted1_airport_history_key		as diverted_airport_history_key
     , diverted1_tail_nbr					as diverted_tail_nbr
     , diverted1_wheels_on_tmstz_lcl		as diverted_wheels_on_tmstz_lcl
     , diverted1_wheels_on_tmstz_utc		as diverted_wheels_on_tmstz_utc
     , diverted1_wheels_off_tmstz_lcl		as diverted_wheels_off_tmstz_lcl
     , diverted1_wheels_off_tmstz_utc		as diverted_wheels_off_tmstz_utc
     , diverted1_total_ground_time_min		as diverted_total_ground_time_min
     , diverted1_longest_ground_time_min	as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1
and diverted1_airport_history_id is not null
union
SELECT flight_key --, flight_key_comp
     , 2::smallint as diversion_nbr
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code				as original_arrive_airport_oai_code
	 , arrive_airport_from_date				as original_arrive_airport_from_date
	 , arrive_airport_history_id			as original_arrive_airport_history_id
	 , arrive_airport_history_key			as original_arrive_airport_history_key
     , diverted2_airport_oai_code			as diverted_airport_oai_code
     , diverted2_airport_from_date			as diverted_airport_from_date
     , diverted2_airport_history_id			as diverted_airport_history_id
     , diverted2_airport_history_key		as diverted_airport_history_key
     , diverted2_tail_nbr					as diverted_tail_nbr
     , diverted2_wheels_on_tmstz_lcl		as diverted_wheels_on_tmstz_lcl
     , diverted2_wheels_on_tmstz_utc		as diverted_wheels_on_tmstz_utc
     , diverted2_wheels_off_tmstz_lcl		as diverted_wheels_off_tmstz_lcl
     , diverted2_wheels_off_tmstz_utc		as diverted_wheels_off_tmstz_utc
     , diverted2_total_ground_time_min		as diverted_total_ground_time_min
     , diverted2_longest_ground_time_min	as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1
and diverted2_airport_history_id is not null
union
SELECT flight_key --, flight_key_comp
     , 3::smallint as diversion_nbr
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code				as original_arrive_airport_oai_code
	 , arrive_airport_from_date				as original_arrive_airport_from_date
	 , arrive_airport_history_id			as original_arrive_airport_history_id
	 , arrive_airport_history_key			as original_arrive_airport_history_key
     , diverted3_airport_oai_code			as diverted_airport_oai_code
     , diverted3_airport_from_date			as diverted_airport_from_date
     , diverted3_airport_history_id			as diverted_airport_history_id
     , diverted3_airport_history_key		as diverted_airport_history_key
     , diverted3_tail_nbr					as diverted_tail_nbr
     , diverted3_wheels_on_tmstz_lcl		as diverted_wheels_on_tmstz_lcl
     , diverted3_wheels_on_tmstz_utc		as diverted_wheels_on_tmstz_utc
     , diverted3_wheels_off_tmstz_lcl		as diverted_wheels_off_time_tmstz_lcl
     , diverted3_wheels_off_tmstz_utc		as diverted_wheels_off_time_tmstz_utc
     , diverted3_total_ground_time_min		as diverted_total_ground_time_min
     , diverted3_longest_ground_time_min	as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1
and diverted3_airport_history_id is not null
union
SELECT flight_key --, flight_key_comp
     , 4::smallint as diversion_nbr
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code				as original_arrive_airport_oai_code
	 , arrive_airport_from_date				as original_arrive_airport_from_date
	 , arrive_airport_history_id			as original_arrive_airport_history_id
	 , arrive_airport_history_key			as original_arrive_airport_history_key
     , diverted4_airport_oai_code			as diverted_airport_oai_code
     , diverted4_airport_from_date			as diverted_airport_from_date
     , diverted4_airport_history_id			as diverted_airport_history_id
     , diverted4_airport_history_key		as diverted_airport_history_key
     , diverted4_tail_nbr					as diverted_tail_nbr
     , diverted4_wheels_on_tmstz_lcl		as diverted_wheels_on_tmstz_lcl
     , diverted4_wheels_on_tmstz_utc		as diverted_wheels_on_tmstz_utc
     , diverted4_wheels_off_tmstz_lcl		as diverted_wheels_off_tmstz_lcl
     , diverted4_wheels_off_tmstz_utc		as diverted_wheels_off_tmstz_utc
     , diverted4_total_ground_time_min		as diverted_total_ground_time_min
     , diverted4_longest_ground_time_min	as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1
and diverted4_airport_history_id is not null
union
SELECT flight_key --, flight_key_comp
     , 5::smallint as diversion_nbr
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code				as original_arrive_airport_oai_code
	 , arrive_airport_from_date				as original_arrive_airport_from_date
	 , arrive_airport_history_id			as original_arrive_airport_history_id
	 , arrive_airport_history_key			as original_arrive_airport_history_key
     , diverted5_airport_oai_code			as diverted_airport_oai_code
     , diverted5_airport_from_date			as diverted_airport_from_date
     , diverted5_airport_history_id			as diverted_airport_history_id
     , diverted5_airport_history_key		as diverted_airport_history_key
     , diverted5_tail_nbr					as diverted_tail_nbr
     , diverted5_wheels_on_tmstz_lcl		as diverted_wheels_on_tmstz_lcl
     , diverted5_wheels_on_tmstz_utc		as diverted_wheels_on_tmstz_utc
     , diverted5_wheels_off_tmstz_lcl		as diverted_wheels_off_tmstz_lcl
     , diverted5_wheels_off_tmstz_utc		as diverted_wheels_off_tmstz_utc
     , diverted5_total_ground_time_min		as diverted_total_ground_time_min
     , diverted5_longest_ground_time_min	as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where diverted_ind = 1
and diverted5_airport_history_id is not null;


-- 4.5. air_oai_facts.airline_flights_scheduled
-- 4.5.1. base data insert (completed flights)
drop table if exists air_oai_facts.airline_flights_scheduled cascade;
create table air_oai_facts.airline_flights_scheduled 
as 
SELECT flight_key --, flight_key_comp
	 , flight_date
	 , airline_oai_code
	 , airline_entity_from_date
	 , airline_entity_id
	 , airline_entity_key
	 , flight_nbr
	 , flight_count
	 , tail_nbr
	 , depart_airport_oai_code
	 , depart_airport_from_date
	 , depart_airport_history_id
	 , depart_airport_history_key
	 , arrive_airport_oai_code
	 , arrive_airport_from_date
	 , arrive_airport_history_id
	 , arrive_airport_history_key
	 , distance_smi
	 , distance_nmi
	 , distance_kmt
	 , distance_group_id
	 , depart_time_block
	 , arrive_time_block
	 , report_depart_tmstz_lcl
	 , report_depart_tmstz_utc
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_lcl + (interval '24 hours')
	        else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
	 , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc 
	        then report_arrive_tmstz_utc + (interval '24 hours')
	        else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
	 , report_elapsed_time_min
     , flight_status  
	 , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp(0) as updated_ts 
FROM air_oai_facts.airline_flight_performance_integrated_mv
where cancelled_ind = 0 and diverted_ind = 0;

-- 4.5.2. update flight status in airline_flights_scheduled 
-- derived from airline_flights_cancelled and airline_flights_diverted
/*
update air_oai_facts.airline_flights_scheduled
set updated_by = current_user
	, updated_ts = now()
    , flight_status = a.flight_status
from (select flight_key, flight_status from air_oai_facts.airline_flights_cancelled) a
where air_oai_facts.airline_flights_scheduled.flight_key = a.flight_key; -- zero

update air_oai_facts.airline_flights_scheduled
set updated_by = current_user
	, updated_ts = now()
    , flight_status = a.flight_status
from (select flight_key, flight_status from air_oai_facts.airline_flights_diverted) a
where air_oai_facts.airline_flights_scheduled.flight_key = a.flight_key; -- zero
*/

-- derived from airline_flights_completed
update air_oai_facts.airline_flights_scheduled
set updated_by = current_user
	, updated_ts = now()
    , flight_status = a.flight_status
from (select flight_key, flight_status from air_oai_facts.airline_flights_completed) a
where air_oai_facts.airline_flights_scheduled.flight_key = a.flight_key; -- all

-- 4.5.3. insert cancelled flights into airline_flights_scheduled
INSERT INTO air_oai_facts.airline_flights_scheduled
SELECT flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc, report_arrive_tmstz_lcl, report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , created_by, created_ts, updated_by, updated_ts
FROM air_oai_facts.airline_flights_cancelled;

-- 4.5.4. insert diverted flights into airline_flights_scheduled
INSERT INTO air_oai_facts.airline_flights_scheduled
SELECT flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc, report_arrive_tmstz_lcl, report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , created_by, created_ts, updated_by, updated_ts
FROM air_oai_facts.airline_flights_diverted;

-- 5. add keys and indexes
-- air_oai_facts.airline_flights_completed
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_pk primary key (flight_key);
create unique index airline_flights_completed_ak on air_oai_facts.airline_flights_completed(airline_oai_code, flight_nbr, flight_date, depart_airport_oai_code);

create index airline_flights_completed_carrier_idx on air_oai_facts.airline_flights_completed (airline_oai_code);
create index airline_flights_completed_flight_date_idx on air_oai_facts.airline_flights_completed (flight_date);
create index airline_flights_completed_flight_lane_idx on air_oai_facts.airline_flights_completed (depart_airport_oai_code, arrive_airport_oai_code);
create index airline_flights_completed_depart_airport_idx on air_oai_facts.airline_flights_completed (depart_airport_oai_code);
create index airline_flights_completed_arrive_airport_idx on air_oai_facts.airline_flights_completed (arrive_airport_oai_code);

alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_arrive_airport_key_fk 
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_flights_cancelled
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_pk primary key (flight_key);
create unique index airline_flights_cancelled_ak on air_oai_facts.airline_flights_cancelled (airline_oai_code, flight_nbr, flight_date, depart_airport_oai_code);

create index airline_flights_cancelled_airline_idx on air_oai_facts.airline_flights_cancelled (airline_oai_code);
create index airline_flights_cancelled_flight_date_idx on air_oai_facts.airline_flights_cancelled (flight_date);
create index airline_flights_cancelled_flight_lane_idx on air_oai_facts.airline_flights_cancelled (depart_airport_oai_code, arrive_airport_oai_code);
create index airline_flights_cancelled_depart_airport_idx on air_oai_facts.airline_flights_cancelled (depart_airport_oai_code);
create index airline_flights_cancelled_arrive_airport_idx on air_oai_facts.airline_flights_cancelled (arrive_airport_oai_code);

alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_arrive_airport_key_fk 
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_flights_diverted
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_pk primary key (flight_key);
create unique index airline_flights_diverted_ak on air_oai_facts.airline_flights_diverted (airline_oai_code, flight_nbr, flight_date, depart_airport_oai_code);

create index airline_flights_diverted_carrier_idx on air_oai_facts.airline_flights_diverted (airline_oai_code);
create index airline_flights_diverted_flight_date_idx on air_oai_facts.airline_flights_diverted (flight_date);
create index airline_flights_diverted_flight_lane_idx on air_oai_facts.airline_flights_diverted(depart_airport_oai_code, arrive_airport_oai_code);
create index airline_flights_diverted_depart_airport_idx on air_oai_facts.airline_flights_diverted (depart_airport_oai_code);
create index airline_flights_diverted_arrive_airport_idx on air_oai_facts.airline_flights_diverted (arrive_airport_oai_code);

alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_arrive_airport_key_fk 
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_flights_diverted_legs
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_pk primary key (flight_key, diversion_nbr);
create unique index airline_flights_diverted_legs_ak on air_oai_facts.airline_flights_diverted_legs (airline_oai_code, flight_nbr, flight_date, depart_airport_oai_code, diversion_nbr);

create index airline_flights_diverted_legs_airline_idx on air_oai_facts.airline_flights_diverted_legs (airline_oai_code);
create index airline_flights_diverted_legs_flight_date_idx on air_oai_facts.airline_flights_diverted_legs (flight_date);
create index airline_flights_diverted_legs_flight_lane_idx on air_oai_facts.airline_flights_diverted_legs (depart_airport_oai_code, original_arrive_airport_oai_code);
create index airline_flights_diverted_legs_depart_airport_idx on air_oai_facts.airline_flights_diverted_legs (depart_airport_oai_code);
create index airline_flights_diverted_legs_arrive_airport_idx on air_oai_facts.airline_flights_diverted_legs (original_arrive_airport_oai_code);

alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_arrive_airport_id_fk 
foreign key (original_arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_diverted_airport_id_fk 
foreign key (diverted_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_arrive_airport_key_fk 
foreign key (original_arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_diverted_airport_key_fk 
foreign key (diverted_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- air_oai_facts.airline_flights_scheduled
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_pk primary key (flight_key);
create unique index airline_flights_scheduled_ak on air_oai_facts.airline_flights_scheduled(airline_oai_code, flight_nbr, flight_date, depart_airport_oai_code); --natural key

create index airline_flights_scheduled_carrier_idx on air_oai_facts.airline_flights_scheduled (airline_oai_code);
create index airline_flights_scheduled_flight_date_idx on air_oai_facts.airline_flights_scheduled (flight_date);
create index airline_flights_scheduled_flight_lane_idx on air_oai_facts.airline_flights_scheduled (depart_airport_oai_code, arrive_airport_oai_code);
create index airline_flights_scheduled_depart_airport_idx on air_oai_facts.airline_flights_scheduled (depart_airport_oai_code);
create index airline_flights_scheduled_arrive_airport_idx on air_oai_facts.airline_flights_scheduled (arrive_airport_oai_code);

alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_airline_id_fk 
foreign key (airline_entity_id) references air_oai_dims.airline_entities (airline_entity_id);
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_depart_airport_id_fk 
foreign key (depart_airport_history_id) references air_oai_dims.airport_history (airport_history_id);
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_arrive_airport_id_fk 
foreign key (arrive_airport_history_id) references air_oai_dims.airport_history (airport_history_id);

alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_airline_key_fk 
foreign key (airline_entity_key) references air_oai_dims.airline_entities (airline_entity_key);
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_depart_airport_key_fk 
foreign key (depart_airport_history_key) references air_oai_dims.airport_history (airport_history_key);
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_arrive_airport_key_fk 
foreign key (arrive_airport_history_key) references air_oai_dims.airport_history (airport_history_key);

-- 6. create presentation layer views
-- drop view if exists airlines_pg.airline_flights_completed_v;
create or replace view airlines_pg.airline_flights_completed_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::date as actual_arrive_date_lcl
	, actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::date as actual_arrive_date_utc
	, actual_elapsed_time_min
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::date as wheels_on_date_lcl
	, wheels_on_tmstz_utc, wheels_on_tmstz_utc::date as wheels_on_date_utc
	, airborne_time_min, taxi_out_min, taxi_in_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
	, airline_delay_min, weather_delay_min, nas_delay_min, security_delay_min, late_aircraft_delay_min
FROM air_oai_facts.airline_flights_completed;

-- drop view if exists airlines_pg.airline_flights_cancelled_v;
create or replace view airlines_pg.airline_flights_cancelled_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, taxi_out_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
FROM air_oai_facts.airline_flights_cancelled;

-- drop view if exists airlines_pg.airline_flights_diverted_v;
create or replace view airlines_pg.airline_flights_diverted_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::date as actual_arrive_date_lcl
	, actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::date as actual_arrive_date_utc
	, actual_elapsed_time_min
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::date as wheels_on_date_lcl
	, wheels_on_tmstz_utc, wheels_on_tmstz_utc::date as wheels_on_date_utc
	, airborne_time_min, taxi_out_min, taxi_in_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
FROM air_oai_facts.airline_flights_diverted;

-- drop view if exists airlines_pg.airline_flights_diverted_legs_v:
create or replace view airlines_pg.airline_flights_diverted_legs_v as
SELECT flight_key, diversion_nbr, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, original_arrive_airport_oai_code, original_arrive_airport_from_date, original_arrive_airport_history_id, original_arrive_airport_history_key
	, diverted_airport_oai_code, diverted_airport_from_date, diverted_airport_history_id, diverted_airport_history_key
	, diverted_tail_nbr
	, diverted_wheels_on_tmstz_lcl, diverted_wheels_on_tmstz_utc
	, diverted_wheels_off_tmstz_lcl, diverted_wheels_off_tmstz_utc
	, diverted_total_ground_time_min, diverted_longest_ground_time_min
FROM air_oai_facts.airline_flights_diverted_legs;

-- drop view if exists airlines_pg.airline_flights_scheduled_v;
create or replace view airlines_pg.airline_flights_scheduled_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min
FROM air_oai_facts.airline_flights_scheduled;