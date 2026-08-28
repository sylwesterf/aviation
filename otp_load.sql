-- OTP (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline On-Time Performance Data Database > Reporting Carrier On-Time Performance (1987-present)
-- https://transtats.bts.gov/Tables.asp?QO_VQ=EFD&QO_anzr=Nv4yv0r%FDb0-gvzr%FDcr4s14zn0pr%FDQn6n&QO_fu146_anzr=b0-gvzr

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. create air_oai_facts.airline_flight_performance_fdw table in redshift
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

-- 1. define a table we'll be copying the data to
DROP TABLE IF EXISTS air_oai_facts.airline_flight_performance_fdw CASCADE;
CREATE TABLE air_oai_facts.airline_flight_performance_fdw
(
    year_nbr                          SMALLINT     NULL,
    quarter_nbr                       SMALLINT     NULL,
    month_nbr                         SMALLINT     NULL,
    day_of_month                      SMALLINT     NULL,
    day_of_week                       SMALLINT     NULL,
    flight_date                       DATE         NULL,
    airline_unique_oai_code           VARCHAR(10)  NULL,
    airline_usdot_id                  INTEGER      NULL,
    airline_oai_code                  CHAR(3)      NULL,
    tail_nbr                          VARCHAR(7)   NULL,
    flight_nbr                        VARCHAR(4)   NULL,
    depart_airport_oai_id             INTEGER      NULL,
    depart_airport_seq_id             INTEGER      NULL,
    depart_city_market_id             INTEGER      NULL,
    depart_airport_oai_code           CHAR(3)      NULL,
    depart_city_name                  VARCHAR(125) NULL,
    depart_state_iso_code             CHAR(2)      NULL,
    depart_state_fips_code            VARCHAR(3)   NULL,
    depart_state_name                 VARCHAR(125) NULL,
    depart_world_area_oai_id          SMALLINT     NULL,
    arrive_airport_oai_id             INTEGER      NULL,
    arrive_airport_seq_oai_id         INTEGER      NULL,
    arrive_city_market_id             INTEGER      NULL,
    arrive_airport_oai_code           CHAR(3)      NULL,
    arrive_city_name                  VARCHAR(125) NULL,
    arrive_state_iso_code             CHAR(2)      NULL,
    arrive_state_fips_code            VARCHAR(3)   NULL,
    arrive_state_name                 VARCHAR(125) NULL,
    arrive_world_area_oai_id          SMALLINT     NULL,
    report_depart_time_lcl            CHAR(4)      NULL,
    actual_depart_time_lcl            CHAR(4)      NULL,
    depart_delay_min                  REAL         NULL,
    depart_delay_pos_min              REAL         NULL,
    depart_delay_15min_ind            REAL         NULL,
    depart_delay_group_id             SMALLINT     NULL,
    depart_time_block                 VARCHAR(10)  NULL,
    taxi_out_min                      REAL         NULL,
    wheels_off_time_lcl               CHAR(4)      NULL,
    wheels_on_time_lcl                CHAR(4)      NULL,
    taxi_in_min                       REAL         NULL,
    report_arrive_time_lcl            CHAR(4)      NULL,
    actual_arrive_time_lcl            CHAR(4)      NULL,
    arrive_delay_min                  REAL         NULL,
    arrive_delay_pos_min              REAL         NULL,
    arrive_delay_15min_ind            REAL         NULL,
    arrive_delay_group_id             SMALLINT     NULL,
    arrive_time_block                 VARCHAR(10)  NULL,
    cancelled_ind                     REAL         NULL,
    cancellation_code                 VARCHAR(10)  NULL,
    diverted_ind                      REAL         NULL,
    report_elapsed_time_min           REAL         NULL,
    actual_elapsed_time_min           REAL         NULL,
    airborne_time_min                 REAL         NULL,
    flight_count                      REAL         NULL,
    distance_smi                      REAL         NULL,
    distance_group_id                 REAL         NULL,
    airline_delay_min                 REAL         NULL,
    weather_delay_min                 REAL         NULL,
    nas_delay_min                     REAL         NULL,
    security_delay_min                REAL         NULL,
    late_aircraft_delay_min           REAL         NULL,
    first_gate_depart_time            VARCHAR(10)  NULL,
    total_ground_time                 VARCHAR(10)  NULL,
    longest_ground_time               VARCHAR(10)  NULL,
    diverted_airport_landing_count    REAL         NULL,
    diverted_reached_dest_ind         REAL         NULL,
    diverted_actual_elapsed_time_min  REAL         NULL,
    diverted_arrive_delay_min         REAL         NULL,
    diverted_distance_smi             REAL         NULL,
    diverted1_airport_oai_code        CHAR(3)      NULL,
    diverted1_airport_oai_id          INTEGER      NULL,
    diverted1_airport_seq_oai_id      INTEGER      NULL,
    diverted1_wheels_on_time_lcl      CHAR(4)      NULL,
    diverted1_total_ground_time_min   REAL         NULL,
    diverted1_longest_ground_time_min REAL         NULL,
    diverted1_wheels_off_time_lcl     CHAR(4)      NULL,
    diverted1_tail_nbr                VARCHAR(7)   NULL,
    diverted2_airport_oai_code        CHAR(3)      NULL,
    diverted2_airport_oai_id          INTEGER      NULL,
    diverted2_airport_seq_oai_id      INTEGER      NULL,
    diverted2_wheels_on_time_lcl      CHAR(4)      NULL,
    diverted2_total_ground_time_min   REAL         NULL,
    diverted2_longest_ground_time_min REAL         NULL,
    diverted2_wheels_off_time_lcl     CHAR(4)      NULL,
    diverted2_tail_nbr                VARCHAR(7)   NULL,
    diverted3_airport_oai_code        CHAR(3)      NULL,
    diverted3_airport_oai_id          INTEGER      NULL,
    diverted3_airport_seq_oai_id      INTEGER      NULL,
    diverted3_wheels_on_time_lcl      CHAR(4)      NULL,
    diverted3_total_ground_time_min   REAL         NULL,
    diverted3_longest_ground_time_min REAL         NULL,
    diverted3_wheels_off_time_lcl     CHAR(4)      NULL,
    diverted3_tail_nbr                VARCHAR(7)   NULL,
    diverted4_airport_oai_code        CHAR(3)      NULL,
    diverted4_airport_oai_id          INTEGER      NULL,
    diverted4_airport_seq_oai_id      INTEGER      NULL,
    diverted4_wheels_on_time_lcl      CHAR(4)      NULL,
    diverted4_total_ground_time_min   REAL         NULL,
    diverted4_longest_ground_time_min REAL         NULL,
    diverted4_wheels_off_time_lcl     CHAR(4)      NULL,
    diverted4_tail_nbr                VARCHAR(7)   NULL,
    diverted5_airport_oai_code        CHAR(3)      NULL,
    diverted5_airport_oai_id          INTEGER      NULL,
    diverted5_airport_seq_oai_id      INTEGER      NULL,
    diverted5_wheels_on_time_lcl      CHAR(4)      NULL,
    diverted5_total_ground_time_min   REAL         NULL,
    diverted5_longest_ground_time_min REAL         NULL,
    diverted5_wheels_off_time_lcl     CHAR(4)      NULL,
    diverted5_tail_nbr                VARCHAR(7)   NULL
);

-- 2. copy OTP data into air_oai_facts.airline_flight_performance_fdw
-- single file:
--COPY air_oai_facts.airline_flight_performance_fdw
--FROM 's3://src-aviation/OTP/CSV/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_4.csv.gz'
--IAM_ROLE default
--CSV GZIP
--DELIMITER ','
--IGNOREHEADER 1 
--REGION 'us-west-2'

-- multiple files 
COPY air_oai_facts.airline_flight_performance_fdw
FROM 's3://src-aviation/OTP/CSV/'
IAM_ROLE default
CSV GZIP
DELIMITER ','
IGNOREHEADER 1
REGION 'us-west-2'
ACCEPTINVCHARS;

-- 3.1. Materialized view for initial data quality work (removed spaces)
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.airline_flight_performance_mv;
CREATE MATERIALIZED VIEW air_oai_facts.airline_flight_performance_mv
AS
SELECT flight_date
     , airline_oai_code
     , tail_nbr
     , flight_nbr
     , depart_airport_oai_code
     , arrive_airport_oai_code
     , report_depart_time_lcl
     , CASE WHEN REPLACE(actual_depart_time_lcl, ' ', '') = '' THEN NULL
            ELSE actual_depart_time_lcl END::CHAR(4)             AS actual_depart_time_lcl
     , depart_delay_min
     , depart_delay_pos_min
     , depart_delay_15min_ind
     , depart_delay_group_id
     , depart_time_block
     , taxi_out_min
     , CASE WHEN REPLACE(wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE wheels_off_time_lcl END::CHAR(4)                AS wheels_off_time_lcl
     , CASE WHEN REPLACE(wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE wheels_on_time_lcl END::CHAR(4)                 AS wheels_on_time_lcl
     , taxi_in_min
     , report_arrive_time_lcl
     , CASE WHEN REPLACE(actual_arrive_time_lcl, ' ', '') = '' THEN NULL
            ELSE actual_arrive_time_lcl END::CHAR(4)             AS actual_arrive_time_lcl
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
     , CASE WHEN REPLACE(first_gate_depart_time, ' ', '') = '' THEN NULL
            ELSE first_gate_depart_time END::CHAR(4)             AS first_gate_depart_time
     , total_ground_time
     , longest_ground_time
     , diverted_airport_landing_count
     , diverted_reached_dest_ind
     , diverted_actual_elapsed_time_min
     , diverted_arrive_delay_min
     , diverted_distance_smi
     , diverted1_airport_oai_code
     , CASE WHEN REPLACE(diverted1_wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted1_wheels_on_time_lcl END::CHAR(4)       AS diverted1_wheels_on_time_lcl
     , diverted1_total_ground_time_min
     , diverted1_longest_ground_time_min
     , CASE WHEN REPLACE(diverted1_wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted1_wheels_off_time_lcl END::CHAR(4)      AS diverted1_wheels_off_time_lcl
     , diverted1_tail_nbr
     , diverted2_airport_oai_code
     , CASE WHEN REPLACE(diverted2_wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted2_wheels_on_time_lcl END::CHAR(4)       AS diverted2_wheels_on_time_lcl
     , diverted2_total_ground_time_min
     , diverted2_longest_ground_time_min
     , CASE WHEN REPLACE(diverted2_wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted2_wheels_off_time_lcl END::CHAR(4)      AS diverted2_wheels_off_time_lcl
     , diverted2_tail_nbr
     , diverted3_airport_oai_code
     , CASE WHEN REPLACE(diverted3_wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted3_wheels_on_time_lcl END::CHAR(4)       AS diverted3_wheels_on_time_lcl
     , diverted3_total_ground_time_min
     , diverted3_longest_ground_time_min
     , CASE WHEN REPLACE(diverted3_wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted3_wheels_off_time_lcl END::CHAR(4)      AS diverted3_wheels_off_time_lcl
     , diverted3_tail_nbr
     , diverted4_airport_oai_code
     , CASE WHEN REPLACE(diverted4_wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted4_wheels_on_time_lcl END::CHAR(4)       AS diverted4_wheels_on_time_lcl
     , diverted4_total_ground_time_min
     , diverted4_longest_ground_time_min
     , CASE WHEN REPLACE(diverted4_wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted4_wheels_off_time_lcl END::CHAR(4)      AS diverted4_wheels_off_time_lcl
     , diverted4_tail_nbr
     , diverted5_airport_oai_code
     , CASE WHEN REPLACE(diverted5_wheels_on_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted5_wheels_on_time_lcl END::CHAR(4)       AS diverted5_wheels_on_time_lcl
     , diverted5_total_ground_time_min
     , diverted5_longest_ground_time_min
     , CASE WHEN REPLACE(diverted5_wheels_off_time_lcl, ' ', '') = '' THEN NULL
            ELSE diverted5_wheels_off_time_lcl END::CHAR(4)      AS diverted5_wheels_off_time_lcl
     , diverted5_tail_nbr
FROM air_oai_facts.airline_flight_performance_fdw;
 
CREATE OR REPLACE FUNCTION air_oai_facts.f_build_lcl_timestamp(p_date DATE, p_time VARCHAR)
RETURNS TIMESTAMP
STABLE
AS $$
    SELECT CASE
        -- blank / null input
        WHEN $2 IS NULL OR TRIM($2) = '' THEN NULL
        -- not purely numeric (guards against any other garbage values)
        WHEN TRIM($2) !~ '^[0-9]{1,4}$' THEN NULL
        -- minutes portion out of range (00-59)
        WHEN SUBSTRING(LPAD(TRIM($2), 4, '0'), 3, 2)::INT NOT BETWEEN 0 AND 59 THEN NULL
        -- hours portion out of range (00-24, where 24 means midnight next day)
        WHEN LEFT(LPAD(TRIM($2), 4, '0'), 2)::INT NOT BETWEEN 0 AND 24 THEN NULL
        -- the airline-data convention of "24xx" meaning midnight of the next day
        WHEN LEFT(LPAD(TRIM($2), 4, '0'), 2) = '24'
            THEN (($1 + 1)::VARCHAR(10) || ' 00:' ||
                  SUBSTRING(LPAD(TRIM($2), 4, '0'), 3, 2))::TIMESTAMP
        ELSE ($1::VARCHAR(10) || ' ' ||
              LEFT(LPAD(TRIM($2), 4, '0'), 2) || ':' ||
              SUBSTRING(LPAD(TRIM($2), 4, '0'), 3, 2))::TIMESTAMP
    END
$$ LANGUAGE sql;
 
-- 3.2. define a "final" materialized view with some data transformations (timezone, data types)
DROP MATERIALIZED VIEW IF EXISTS air_oai_facts.airline_flight_performance_integrated_mv;
CREATE MATERIALIZED VIEW air_oai_facts.airline_flight_performance_integrated_mv
AS
SELECT MD5(fp.airline_oai_code||'|'||fp.flight_nbr||'|'||fp.flight_date::VARCHAR(10)||'|'||fp.depart_airport_oai_code)::CHAR(32) AS flight_key
     , fp.airline_oai_code||'|'||fp.flight_nbr||'|'||fp.flight_date::VARCHAR(10)||'|'||fp.depart_airport_oai_code               AS flight_key_comp
     , fp.flight_date::DATE                                                                                                       AS flight_date
     , fp.airline_oai_code::VARCHAR(3)                                                                                            AS airline_oai_code
     , ae.source_from_date                                                                                                        AS airline_entity_from_date
     , ae.airline_entity_id                                                                                                       AS airline_entity_id
     , ae.airline_entity_key                                                                                                      AS airline_entity_key
     , LPAD(fp.flight_nbr, 4, '0')::CHAR(4)                                                                                      AS flight_nbr
     , fp.flight_count::SMALLINT                                                                                                  AS flight_count
     , fp.tail_nbr::VARCHAR(10)                                                                                                   AS tail_nbr
     , fp.depart_airport_oai_code::CHAR(3)                                                                                       AS depart_airport_oai_code
     , a.effective_from_date                                                                                                      AS depart_airport_from_date
     , a.airport_history_id                                                                                                       AS depart_airport_history_id
     , a.airport_history_key                                                                                                      AS depart_airport_history_key
     , a.time_zone_name                                                                                                           AS depart_time_zone_name
     , fp.arrive_airport_oai_code::CHAR(3)                                                                                       AS arrive_airport_oai_code
     , b.effective_from_date                                                                                                      AS arrive_airport_from_date
     , b.airport_history_id                                                                                                       AS arrive_airport_history_id
     , b.airport_history_key                                                                                                      AS arrive_airport_history_key
     , b.time_zone_name                                                                                                           AS arrive_time_zone_name
     , CASE WHEN fp.cancelled_ind = 1                       THEN 'cancelled'
            WHEN fp.diverted_ind  = 1                       THEN 'diverted'
            WHEN fp.airline_delay_min::SMALLINT IS NOT NULL THEN 'arrived_delayed'
            ELSE 'arrived_on_time'
       END::VARCHAR(25)                                                                                                           AS flight_status
     , fp.cancelled_ind::SMALLINT                                                                                                 AS cancelled_ind
     , fp.cancellation_code::VARCHAR(25)                                                                                         AS cancellation_code
     , fp.diverted_ind::SMALLINT                                                                                                  AS diverted_ind
     , fp.distance_smi::SMALLINT                                                                                                  AS distance_smi
     , (fp.distance_smi / 1.1508::FLOAT)::SMALLINT                                                                               AS distance_nmi
     , (fp.distance_smi * 1.60934::FLOAT)::SMALLINT                                                                              AS distance_kmt
     , fp.distance_group_id::SMALLINT                                                                                             AS distance_group_id
     , fp.depart_time_block
     , fp.arrive_time_block
     , fp.report_depart_time_lcl
     , CONVERT_TIMEZONE('UTC', a.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.report_depart_time_lcl))   AS report_depart_tmstz_lcl
     , CONVERT_TIMEZONE(a.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.report_depart_time_lcl))   AS report_depart_tmstz_utc
     , fp.report_arrive_time_lcl
     , CONVERT_TIMEZONE('UTC', b.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.report_arrive_time_lcl))   AS report_arrive_tmstz_lcl
     , CONVERT_TIMEZONE(b.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.report_arrive_time_lcl))   AS report_arrive_tmstz_utc
     , fp.report_elapsed_time_min
     , fp.actual_depart_time_lcl
     , CONVERT_TIMEZONE('UTC', a.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.actual_depart_time_lcl))   AS actual_depart_tmstz_lcl
     , CONVERT_TIMEZONE(a.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.actual_depart_time_lcl))   AS actual_depart_tmstz_utc
     , fp.actual_arrive_time_lcl
     , CONVERT_TIMEZONE('UTC', b.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.actual_arrive_time_lcl))   AS actual_arrive_tmstz_lcl
     , CONVERT_TIMEZONE(b.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.actual_arrive_time_lcl))   AS actual_arrive_tmstz_utc
 
     , fp.actual_elapsed_time_min
     , fp.wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', a.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.wheels_off_time_lcl))      AS wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(a.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.wheels_off_time_lcl))      AS wheels_off_tmstz_utc
     , fp.wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', b.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.wheels_on_time_lcl))       AS wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(b.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.wheels_on_time_lcl))       AS wheels_on_tmstz_utc
 
     , fp.airborne_time_min
     , fp.taxi_out_min::SMALLINT                                                                                                  AS taxi_out_min
     , fp.taxi_in_min::SMALLINT                                                                                                   AS taxi_in_min
     , fp.first_gate_depart_time
     , CONVERT_TIMEZONE('UTC', a.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.first_gate_depart_time))   AS first_gate_depart_tmstz_lcl
     , CONVERT_TIMEZONE(a.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.first_gate_depart_time))   AS first_gate_depart_tmstz_utc
     , NULLIF(TRIM(fp.total_ground_time), '')::NUMERIC(3,0)::SMALLINT                                                            AS total_ground_time
     , NULLIF(TRIM(fp.longest_ground_time), '')::NUMERIC(3,0)::SMALLINT                                                          AS longest_ground_time
     , fp.airline_delay_min::SMALLINT                                                                                             AS airline_delay_min
     , fp.weather_delay_min::SMALLINT                                                                                             AS weather_delay_min
     , fp.nas_delay_min::SMALLINT                                                                                                 AS nas_delay_min
     , fp.security_delay_min::SMALLINT                                                                                            AS security_delay_min
     , fp.late_aircraft_delay_min::SMALLINT                                                                                       AS late_aircraft_delay_min
     , fp.diverted_airport_landing_count::SMALLINT                                                                                AS diverted_airport_landing_count
     , fp.diverted_reached_dest_ind::SMALLINT                                                                                     AS diverted_reached_dest_ind
     , fp.diverted_actual_elapsed_time_min::SMALLINT                                                                              AS diverted_actual_elapsed_time_min
     , fp.diverted_arrive_delay_min::SMALLINT                                                                                     AS diverted_arrive_delay_min
     , fp.diverted_distance_smi::INTEGER                                                                                          AS diverted_distance_smi
     , fp.diverted1_airport_oai_code::CHAR(3)                                                                                    AS diverted1_airport_oai_code
     , d1.effective_from_date                                                                                                     AS diverted1_airport_from_date
     , d1.airport_history_id                                                                                                      AS diverted1_airport_history_id
     , d1.airport_history_key                                                                                                     AS diverted1_airport_history_key
     , d1.time_zone_name                                                                                                          AS diverted1_time_zone_name
     , fp.diverted1_tail_nbr::VARCHAR(10)                                                                                         AS diverted1_tail_nbr
     , fp.diverted1_wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', d1.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted1_wheels_on_time_lcl))   AS diverted1_wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(d1.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted1_wheels_on_time_lcl))   AS diverted1_wheels_on_tmstz_utc
     , fp.diverted1_wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', d1.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted1_wheels_off_time_lcl))  AS diverted1_wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(d1.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted1_wheels_off_time_lcl))  AS diverted1_wheels_off_tmstz_utc
     , fp.diverted1_total_ground_time_min::SMALLINT                                                                               AS diverted1_total_ground_time_min
     , fp.diverted1_longest_ground_time_min::SMALLINT                                                                             AS diverted1_longest_ground_time_min
     , fp.diverted2_airport_oai_code::CHAR(3)                                                                                    AS diverted2_airport_oai_code
     , d2.effective_from_date                                                                                                     AS diverted2_airport_from_date
     , d2.airport_history_id                                                                                                      AS diverted2_airport_history_id
     , d2.airport_history_key                                                                                                     AS diverted2_airport_history_key
     , d2.time_zone_name                                                                                                          AS diverted2_time_zone_name
     , fp.diverted2_tail_nbr::VARCHAR(10)                                                                                         AS diverted2_tail_nbr
     , fp.diverted2_wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', d2.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted2_wheels_on_time_lcl))   AS diverted2_wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(d2.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted2_wheels_on_time_lcl))   AS diverted2_wheels_on_tmstz_utc
     , fp.diverted2_wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', d2.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted2_wheels_off_time_lcl))  AS diverted2_wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(d2.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted2_wheels_off_time_lcl))  AS diverted2_wheels_off_tmstz_utc
     , fp.diverted2_total_ground_time_min::SMALLINT                                                                               AS diverted2_total_ground_time_min
     , fp.diverted2_longest_ground_time_min::SMALLINT                                                                             AS diverted2_longest_ground_time_min
     , fp.diverted3_airport_oai_code::CHAR(3)                                                                                    AS diverted3_airport_oai_code
     , d3.effective_from_date                                                                                                     AS diverted3_airport_from_date
     , d3.airport_history_id                                                                                                      AS diverted3_airport_history_id
     , d3.airport_history_key                                                                                                     AS diverted3_airport_history_key
     , d3.time_zone_name                                                                                                          AS diverted3_time_zone_name
     , fp.diverted3_tail_nbr::VARCHAR(10)                                                                                         AS diverted3_tail_nbr
     , fp.diverted3_wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', d3.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted3_wheels_on_time_lcl))   AS diverted3_wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(d3.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted3_wheels_on_time_lcl))   AS diverted3_wheels_on_tmstz_utc
     , fp.diverted3_wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', d3.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted3_wheels_off_time_lcl))  AS diverted3_wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(d3.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted3_wheels_off_time_lcl))  AS diverted3_wheels_off_tmstz_utc
     , fp.diverted3_total_ground_time_min::SMALLINT                                                                               AS diverted3_total_ground_time_min
     , fp.diverted3_longest_ground_time_min::SMALLINT                                                                             AS diverted3_longest_ground_time_min
     , fp.diverted4_airport_oai_code::CHAR(3)                                                                                    AS diverted4_airport_oai_code
     , d4.effective_from_date                                                                                                     AS diverted4_airport_from_date
     , d4.airport_history_id                                                                                                      AS diverted4_airport_history_id
     , d4.airport_history_key                                                                                                     AS diverted4_airport_history_key
     , d4.time_zone_name                                                                                                          AS diverted4_time_zone_name
     , fp.diverted4_tail_nbr::VARCHAR(10)                                                                                         AS diverted4_tail_nbr
     , fp.diverted4_wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', d4.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted4_wheels_on_time_lcl))   AS diverted4_wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(d4.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted4_wheels_on_time_lcl))   AS diverted4_wheels_on_tmstz_utc
     , fp.diverted4_wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', d4.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted4_wheels_off_time_lcl))  AS diverted4_wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(d4.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted4_wheels_off_time_lcl))  AS diverted4_wheels_off_tmstz_utc
     , fp.diverted4_total_ground_time_min::SMALLINT                                                                               AS diverted4_total_ground_time_min
     , fp.diverted4_longest_ground_time_min::SMALLINT                                                                             AS diverted4_longest_ground_time_min
     , fp.diverted5_airport_oai_code::CHAR(3)                                                                                    AS diverted5_airport_oai_code
     , d5.effective_from_date                                                                                                     AS diverted5_airport_from_date
     , d5.airport_history_id                                                                                                      AS diverted5_airport_history_id
     , d5.airport_history_key                                                                                                     AS diverted5_airport_history_key
     , d5.time_zone_name                                                                                                          AS diverted5_time_zone_name
     , fp.diverted5_tail_nbr::VARCHAR(10)                                                                                         AS diverted5_tail_nbr
     , fp.diverted5_wheels_on_time_lcl
     , CONVERT_TIMEZONE('UTC', d5.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted5_wheels_on_time_lcl))   AS diverted5_wheels_on_tmstz_lcl
     , CONVERT_TIMEZONE(d5.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted5_wheels_on_time_lcl))   AS diverted5_wheels_on_tmstz_utc
     , fp.diverted5_wheels_off_time_lcl
     , CONVERT_TIMEZONE('UTC', d5.time_zone_name,
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted5_wheels_off_time_lcl))  AS diverted5_wheels_off_tmstz_lcl
     , CONVERT_TIMEZONE(d5.time_zone_name, 'UTC',
           air_oai_facts.f_build_lcl_timestamp(fp.flight_date, fp.diverted5_wheels_off_time_lcl))  AS diverted5_wheels_off_tmstz_utc
     , fp.diverted5_total_ground_time_min::SMALLINT                                                                               AS diverted5_total_ground_time_min
     , fp.diverted5_longest_ground_time_min::SMALLINT                                                                             AS diverted5_longest_ground_time_min
FROM air_oai_facts.airline_flight_performance_mv fp
LEFT OUTER JOIN
(
    SELECT airline_entity_id, airline_entity_key, airline_oai_code, source_from_date, source_thru_date
    FROM air_oai_dims.airline_entities
    WHERE operating_region_code = 'Domestic'
) ae ON fp.airline_oai_code = ae.airline_oai_code
    AND fp.flight_date BETWEEN ae.source_from_date AND COALESCE(ae.source_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) a ON fp.depart_airport_oai_code = a.airport_oai_code
   AND fp.flight_date BETWEEN a.effective_from_date AND COALESCE(a.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) b ON fp.arrive_airport_oai_code = b.airport_oai_code
   AND fp.flight_date BETWEEN b.effective_from_date AND COALESCE(b.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) d1 ON fp.diverted1_airport_oai_code = d1.airport_oai_code
    AND fp.flight_date BETWEEN d1.effective_from_date AND COALESCE(d1.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) d2 ON fp.diverted2_airport_oai_code = d2.airport_oai_code
    AND fp.flight_date BETWEEN d2.effective_from_date AND COALESCE(d2.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) d3 ON fp.diverted3_airport_oai_code = d3.airport_oai_code
    AND fp.flight_date BETWEEN d3.effective_from_date AND COALESCE(d3.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) d4 ON fp.diverted4_airport_oai_code = d4.airport_oai_code
    AND fp.flight_date BETWEEN d4.effective_from_date AND COALESCE(d4.effective_thru_date, CURRENT_DATE)
LEFT OUTER JOIN
(
    SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date, time_zone_name
    FROM air_oai_dims.airport_history
) d5 ON fp.diverted5_airport_oai_code = d5.airport_oai_code
    AND fp.flight_date BETWEEN d5.effective_from_date AND COALESCE(d5.effective_thru_date, CURRENT_DATE);

-- 4.1. air_oai_facts.airline_flights_completed
DROP TABLE IF EXISTS air_oai_facts.airline_flights_completed;
CREATE TABLE air_oai_facts.airline_flights_completed
(
    flight_key                      VARCHAR(255)    NOT NULL  
  , flight_date                     DATE
  , airline_oai_code                VARCHAR(10)
  , airline_entity_from_date        DATE
  , airline_entity_id               INTEGER
  , airline_entity_key              INTEGER
  , flight_nbr                      VARCHAR(10)
  , flight_count                    INTEGER
  , tail_nbr                        VARCHAR(10)
  , depart_airport_oai_code         VARCHAR(10)
  , depart_airport_from_date        DATE
  , depart_airport_history_id       INTEGER
  , depart_airport_history_key      INTEGER
  , arrive_airport_oai_code         VARCHAR(10)
  , arrive_airport_from_date        DATE
  , arrive_airport_history_id       INTEGER
  , arrive_airport_history_key      INTEGER
  , distance_smi                    DECIMAL(10,2)
  , distance_nmi                    DECIMAL(10,2)
  , distance_kmt                    DECIMAL(10,2)
  , distance_group_id               INTEGER
  , depart_time_block               VARCHAR(10)
  , arrive_time_block               VARCHAR(10)
  , report_depart_tmstz_lcl         TIMESTAMP
  , report_depart_tmstz_utc         TIMESTAMP
  , report_arrive_tmstz_lcl         TIMESTAMP
  , report_arrive_tmstz_utc         TIMESTAMP
  , report_elapsed_time_min         INTEGER
  , flight_status                   VARCHAR(25)
  , actual_depart_tmstz_lcl         TIMESTAMP
  , actual_depart_tmstz_utc         TIMESTAMP
  , actual_arrive_tmstz_lcl         TIMESTAMP
  , actual_arrive_tmstz_utc         TIMESTAMP
  , actual_elapsed_time_min         INTEGER
  , wheels_off_tmstz_lcl            TIMESTAMP
  , wheels_off_tmstz_utc            TIMESTAMP
  , wheels_on_tmstz_lcl             TIMESTAMP
  , wheels_on_tmstz_utc             TIMESTAMP
  , airborne_time_min               INTEGER
  , taxi_out_min                    INTEGER
  , taxi_in_min                     INTEGER
  , first_gate_depart_tmstz_lcl     TIMESTAMP
  , first_gate_depart_tmstz_utc     TIMESTAMP
  , total_ground_time               INTEGER
  , longest_ground_time             INTEGER
  , airline_delay_min               INTEGER
  , weather_delay_min               INTEGER
  , nas_delay_min                   INTEGER
  , security_delay_min              INTEGER
  , late_aircraft_delay_min         INTEGER
  , created_by                      VARCHAR(32)
  , created_ts                      TIMESTAMP
  , updated_by                      VARCHAR(32)
  , updated_ts                      TIMESTAMP
);

INSERT INTO air_oai_facts.airline_flights_completed
SELECT flight_key
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
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_lcl)
            ELSE report_arrive_tmstz_lcl
       END
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_utc)
            ELSE report_arrive_tmstz_utc
       END
     , report_elapsed_time_min
     , CASE WHEN airline_delay_min IS NOT NULL THEN 'completed-delayed'
            ELSE 'completed-on-time'
       END::VARCHAR(25)
     , actual_depart_tmstz_lcl
     , actual_depart_tmstz_utc
     , CASE WHEN actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
            THEN DATEADD(hour, 24, actual_arrive_tmstz_lcl)
            ELSE actual_arrive_tmstz_lcl
       END
     , CASE WHEN actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
            THEN DATEADD(hour, 24, actual_arrive_tmstz_utc)
            ELSE actual_arrive_tmstz_utc
       END
     , actual_elapsed_time_min
     , wheels_off_tmstz_lcl
     , wheels_off_tmstz_utc
     , CASE WHEN wheels_on_tmstz_utc <= wheels_off_tmstz_utc
            THEN DATEADD(hour, 24, wheels_on_tmstz_lcl)
            ELSE wheels_on_tmstz_lcl
       END
     , CASE WHEN wheels_on_tmstz_utc <= wheels_off_tmstz_utc
            THEN DATEADD(hour, 24, wheels_on_tmstz_utc)
            ELSE wheels_on_tmstz_utc
       END
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
     , CURRENT_USER::VARCHAR(32)
     , GETDATE()::TIMESTAMP
     , NULL::VARCHAR(32)
     , NULL::TIMESTAMP
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE cancelled_ind = 0
  AND diverted_ind  = 0;


-- 4.2. air_oai_facts.airline_flights_cancelled
DROP TABLE IF EXISTS air_oai_facts.airline_flights_cancelled;
CREATE TABLE air_oai_facts.airline_flights_cancelled
(
    flight_key                      VARCHAR(255)    NOT NULL  
  , flight_date                     DATE
  , airline_oai_code                VARCHAR(10)
  , airline_entity_from_date        DATE
  , airline_entity_id               INTEGER
  , airline_entity_key              INTEGER
  , flight_nbr                      VARCHAR(10)
  , flight_count                    INTEGER
  , tail_nbr                        VARCHAR(10)
  , depart_airport_oai_code         VARCHAR(10)
  , depart_airport_from_date        DATE
  , depart_airport_history_id       INTEGER
  , depart_airport_history_key      INTEGER
  , arrive_airport_oai_code         VARCHAR(10)
  , arrive_airport_from_date        DATE
  , arrive_airport_history_id       INTEGER
  , arrive_airport_history_key      INTEGER
  , distance_smi                    DECIMAL(10,2)
  , distance_nmi                    DECIMAL(10,2)
  , distance_kmt                    DECIMAL(10,2)
  , distance_group_id               INTEGER
  , depart_time_block               VARCHAR(10)
  , arrive_time_block               VARCHAR(10)
  , report_depart_tmstz_lcl         TIMESTAMP
  , report_depart_tmstz_utc         TIMESTAMP
  , report_arrive_tmstz_lcl         TIMESTAMP
  , report_arrive_tmstz_utc         TIMESTAMP
  , report_elapsed_time_min         INTEGER
  , flight_status                   VARCHAR(25)
  , actual_depart_tmstz_lcl         TIMESTAMP
  , actual_depart_tmstz_utc         TIMESTAMP
  , wheels_off_tmstz_lcl            TIMESTAMP
  , wheels_off_tmstz_utc            TIMESTAMP
  , taxi_out_min                    INTEGER
  , first_gate_depart_tmstz_lcl     TIMESTAMP
  , first_gate_depart_tmstz_utc     TIMESTAMP
  , total_ground_time               INTEGER
  , longest_ground_time             INTEGER
  , created_by                      VARCHAR(32)
  , created_ts                      TIMESTAMP
  , updated_by                      VARCHAR(32)
  , updated_ts                      TIMESTAMP
);

INSERT INTO air_oai_facts.airline_flights_cancelled
SELECT flight_key
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
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_lcl)
            ELSE report_arrive_tmstz_lcl
       END
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_utc)
            ELSE report_arrive_tmstz_utc
       END
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
     , CURRENT_USER::VARCHAR(32)
     , GETDATE()::TIMESTAMP
     , NULL::VARCHAR(32)
     , NULL::TIMESTAMP
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE cancelled_ind = 1;


-- 4.3. air_oai_facts.airline_flights_diverted
DROP TABLE IF EXISTS air_oai_facts.airline_flights_diverted;
CREATE TABLE air_oai_facts.airline_flights_diverted
(
    flight_key                      VARCHAR(255)    NOT NULL  -- ⬅️ clave del fix
  , flight_date                     DATE
  , airline_oai_code                VARCHAR(10)
  , airline_entity_from_date        DATE
  , airline_entity_id               INTEGER
  , airline_entity_key              INTEGER
  , flight_nbr                      VARCHAR(10)
  , flight_count                    INTEGER
  , tail_nbr                        VARCHAR(10)
  , depart_airport_oai_code         VARCHAR(10)
  , depart_airport_from_date        DATE
  , depart_airport_history_id       INTEGER
  , depart_airport_history_key      INTEGER
  , arrive_airport_oai_code         VARCHAR(10)
  , arrive_airport_from_date        DATE
  , arrive_airport_history_id       INTEGER
  , arrive_airport_history_key      INTEGER
  , distance_smi                    DECIMAL(10,2)
  , distance_nmi                    DECIMAL(10,2)
  , distance_kmt                    DECIMAL(10,2)
  , distance_group_id               INTEGER
  , depart_time_block               VARCHAR(10)
  , arrive_time_block               VARCHAR(10)
  , report_depart_tmstz_lcl         TIMESTAMP
  , report_depart_tmstz_utc         TIMESTAMP
  , report_arrive_tmstz_lcl         TIMESTAMP
  , report_arrive_tmstz_utc         TIMESTAMP
  , report_elapsed_time_min         INTEGER
  , flight_status                   VARCHAR(25)
  , actual_depart_tmstz_lcl         TIMESTAMP
  , actual_depart_tmstz_utc         TIMESTAMP
  , actual_arrive_tmstz_lcl         TIMESTAMP
  , actual_arrive_tmstz_utc         TIMESTAMP
  , actual_elapsed_time_min         INTEGER
  , wheels_off_tmstz_lcl            TIMESTAMP
  , wheels_off_tmstz_utc            TIMESTAMP
  , wheels_on_tmstz_lcl             TIMESTAMP
  , wheels_on_tmstz_utc             TIMESTAMP
  , airborne_time_min               INTEGER
  , taxi_out_min                    INTEGER
  , taxi_in_min                     INTEGER
  , first_gate_depart_tmstz_lcl     TIMESTAMP
  , first_gate_depart_tmstz_utc     TIMESTAMP
  , total_ground_time               INTEGER
  , longest_ground_time             INTEGER
  , created_by                      VARCHAR(32)
  , created_ts                      TIMESTAMP
  , updated_by                      VARCHAR(32)
  , updated_ts                      TIMESTAMP
);

INSERT INTO air_oai_facts.airline_flights_diverted
SELECT flight_key
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
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_lcl)
            ELSE report_arrive_tmstz_lcl
       END
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_utc)
            ELSE report_arrive_tmstz_utc
       END
     , report_elapsed_time_min
     , flight_status
     , actual_depart_tmstz_lcl
     , actual_depart_tmstz_utc
     , CASE WHEN actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
            THEN DATEADD(hour, 24, actual_arrive_tmstz_lcl)
            ELSE actual_arrive_tmstz_lcl
       END
     , CASE WHEN actual_arrive_tmstz_utc <= actual_depart_tmstz_utc
            THEN DATEADD(hour, 24, actual_arrive_tmstz_utc)
            ELSE actual_arrive_tmstz_utc
       END
     , actual_elapsed_time_min
     , wheels_off_tmstz_lcl
     , wheels_off_tmstz_utc
     , CASE WHEN wheels_on_tmstz_utc <= wheels_off_tmstz_utc
            THEN DATEADD(hour, 24, wheels_on_tmstz_lcl)
            ELSE wheels_on_tmstz_lcl
       END
     , CASE WHEN wheels_on_tmstz_utc <= wheels_off_tmstz_utc
            THEN DATEADD(hour, 24, wheels_on_tmstz_utc)
            ELSE wheels_on_tmstz_utc
       END
     , airborne_time_min
     , taxi_out_min
     , taxi_in_min
     , first_gate_depart_tmstz_lcl
     , first_gate_depart_tmstz_utc
     , total_ground_time
     , longest_ground_time
     , CURRENT_USER::VARCHAR(32)
     , GETDATE()::TIMESTAMP
     , NULL::VARCHAR(32)
     , NULL::TIMESTAMP
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1;


-- 4.4. air_oai_facts.airline_flights_diverted_legs
DROP TABLE IF EXISTS air_oai_facts.airline_flights_diverted_legs;
CREATE TABLE air_oai_facts.airline_flights_diverted_legs
(
    flight_key                              VARCHAR(255)    NOT NULL
  , diversion_nbr                           SMALLINT        NOT NULL
  , flight_date                             DATE
  , airline_oai_code                        VARCHAR(10)
  , airline_entity_from_date                DATE
  , airline_entity_id                       VARCHAR(50)     
  , airline_entity_key                      VARCHAR(50)     
  , flight_nbr                              VARCHAR(10)
  , flight_count                            VARCHAR(50)     
  , tail_nbr                                VARCHAR(10)
  , depart_airport_oai_code                 VARCHAR(10)
  , depart_airport_from_date                DATE
  , depart_airport_history_id               VARCHAR(50)     
  , depart_airport_history_key              VARCHAR(50)     
  , original_arrive_airport_oai_code        VARCHAR(10)
  , original_arrive_airport_from_date       DATE
  , original_arrive_airport_history_id      VARCHAR(50)     
  , original_arrive_airport_history_key     VARCHAR(50)    
  , diverted_airport_oai_code               VARCHAR(10)
  , diverted_airport_from_date              DATE
  , diverted_airport_history_id             VARCHAR(50)    
  , diverted_airport_history_key            VARCHAR(50)     
  , diverted_tail_nbr                       VARCHAR(10)
  , diverted_wheels_on_tmstz_lcl            TIMESTAMP
  , diverted_wheels_on_tmstz_utc            TIMESTAMP
  , diverted_wheels_off_tmstz_lcl           TIMESTAMP
  , diverted_wheels_off_tmstz_utc           TIMESTAMP
  , diverted_total_ground_time_min          VARCHAR(50)     
  , diverted_longest_ground_time_min        VARCHAR(50)     
  , created_by                              VARCHAR(32)
  , created_ts                              TIMESTAMP
  , updated_by                              VARCHAR(32)
  , updated_ts                              TIMESTAMP
);

INSERT INTO air_oai_facts.airline_flights_diverted_legs
SELECT flight_key 
     , 1::SMALLINT                                                    AS diversion_nbr
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
     , arrive_airport_oai_code                                        AS original_arrive_airport_oai_code
     , arrive_airport_from_date                                       AS original_arrive_airport_from_date
     , arrive_airport_history_id                                      AS original_arrive_airport_history_id
     , arrive_airport_history_key                                     AS original_arrive_airport_history_key
     , diverted1_airport_oai_code                                     AS diverted_airport_oai_code
     , diverted1_airport_from_date                                    AS diverted_airport_from_date
     , diverted1_airport_history_id                                   AS diverted_airport_history_id
     , diverted1_airport_history_key                                  AS diverted_airport_history_key
     , diverted1_tail_nbr                                             AS diverted_tail_nbr
     , diverted1_wheels_on_tmstz_lcl                                  AS diverted_wheels_on_tmstz_lcl
     , diverted1_wheels_on_tmstz_utc                                  AS diverted_wheels_on_tmstz_utc
     , diverted1_wheels_off_tmstz_lcl                                 AS diverted_wheels_off_tmstz_lcl
     , diverted1_wheels_off_tmstz_utc                                 AS diverted_wheels_off_tmstz_utc
     , diverted1_total_ground_time_min                                AS diverted_total_ground_time_min
     , diverted1_longest_ground_time_min                              AS diverted_longest_ground_time_min
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1
  AND diverted1_airport_history_id IS NOT NULL

UNION

SELECT flight_key
     , 2::SMALLINT                                                    AS diversion_nbr
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
     , arrive_airport_oai_code                                        AS original_arrive_airport_oai_code
     , arrive_airport_from_date                                       AS original_arrive_airport_from_date
     , arrive_airport_history_id                                      AS original_arrive_airport_history_id
     , arrive_airport_history_key                                     AS original_arrive_airport_history_key
     , diverted2_airport_oai_code                                     AS diverted_airport_oai_code
     , diverted2_airport_from_date                                    AS diverted_airport_from_date
     , diverted2_airport_history_id                                   AS diverted_airport_history_id
     , diverted2_airport_history_key                                  AS diverted_airport_history_key
     , diverted2_tail_nbr                                             AS diverted_tail_nbr
     , diverted2_wheels_on_tmstz_lcl                                  AS diverted_wheels_on_tmstz_lcl
     , diverted2_wheels_on_tmstz_utc                                  AS diverted_wheels_on_tmstz_utc
     , diverted2_wheels_off_tmstz_lcl                                 AS diverted_wheels_off_tmstz_lcl
     , diverted2_wheels_off_tmstz_utc                                 AS diverted_wheels_off_tmstz_utc
     , diverted2_total_ground_time_min                                AS diverted_total_ground_time_min
     , diverted2_longest_ground_time_min                              AS diverted_longest_ground_time_min
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1
  AND diverted2_airport_history_id IS NOT NULL

UNION

SELECT flight_key
     , 3::SMALLINT                                                    AS diversion_nbr
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
     , arrive_airport_oai_code                                        AS original_arrive_airport_oai_code
     , arrive_airport_from_date                                       AS original_arrive_airport_from_date
     , arrive_airport_history_id                                      AS original_arrive_airport_history_id
     , arrive_airport_history_key                                     AS original_arrive_airport_history_key
     , diverted3_airport_oai_code                                     AS diverted_airport_oai_code
     , diverted3_airport_from_date                                    AS diverted_airport_from_date
     , diverted3_airport_history_id                                   AS diverted_airport_history_id
     , diverted3_airport_history_key                                  AS diverted_airport_history_key
     , diverted3_tail_nbr                                             AS diverted_tail_nbr
     , diverted3_wheels_on_tmstz_lcl                                  AS diverted_wheels_on_tmstz_lcl
     , diverted3_wheels_on_tmstz_utc                                  AS diverted_wheels_on_tmstz_utc
     , diverted3_wheels_off_tmstz_lcl                                 AS diverted_wheels_off_tmstz_lcl
     , diverted3_wheels_off_tmstz_utc                                 AS diverted_wheels_off_tmstz_utc
     , diverted3_total_ground_time_min                                AS diverted_total_ground_time_min
     , diverted3_longest_ground_time_min                              AS diverted_longest_ground_time_min
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1
  AND diverted3_airport_history_id IS NOT NULL

UNION

SELECT flight_key
     , 4::SMALLINT                                                    AS diversion_nbr
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
     , arrive_airport_oai_code                                        AS original_arrive_airport_oai_code
     , arrive_airport_from_date                                       AS original_arrive_airport_from_date
     , arrive_airport_history_id                                      AS original_arrive_airport_history_id
     , arrive_airport_history_key                                     AS original_arrive_airport_history_key
     , diverted4_airport_oai_code                                     AS diverted_airport_oai_code
     , diverted4_airport_from_date                                    AS diverted_airport_from_date
     , diverted4_airport_history_id                                   AS diverted_airport_history_id
     , diverted4_airport_history_key                                  AS diverted_airport_history_key
     , diverted4_tail_nbr                                             AS diverted_tail_nbr
     , diverted4_wheels_on_tmstz_lcl                                  AS diverted_wheels_on_tmstz_lcl
     , diverted4_wheels_on_tmstz_utc                                  AS diverted_wheels_on_tmstz_utc
     , diverted4_wheels_off_tmstz_lcl                                 AS diverted_wheels_off_tmstz_lcl
     , diverted4_wheels_off_tmstz_utc                                 AS diverted_wheels_off_tmstz_utc
     , diverted4_total_ground_time_min                                AS diverted_total_ground_time_min
     , diverted4_longest_ground_time_min                              AS diverted_longest_ground_time_min
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1
  AND diverted4_airport_history_id IS NOT NULL

UNION

SELECT flight_key
     , 5::SMALLINT                                                    AS diversion_nbr
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
     , arrive_airport_oai_code                                        AS original_arrive_airport_oai_code
     , arrive_airport_from_date                                       AS original_arrive_airport_from_date
     , arrive_airport_history_id                                      AS original_arrive_airport_history_id
     , arrive_airport_history_key                                     AS original_arrive_airport_history_key
     , diverted5_airport_oai_code                                     AS diverted_airport_oai_code
     , diverted5_airport_from_date                                    AS diverted_airport_from_date
     , diverted5_airport_history_id                                   AS diverted_airport_history_id
     , diverted5_airport_history_key                                  AS diverted_airport_history_key
     , diverted5_tail_nbr                                             AS diverted_tail_nbr
     , diverted5_wheels_on_tmstz_lcl                                  AS diverted_wheels_on_tmstz_lcl
     , diverted5_wheels_on_tmstz_utc                                  AS diverted_wheels_on_tmstz_utc
     , diverted5_wheels_off_tmstz_lcl                                 AS diverted_wheels_off_tmstz_lcl
     , diverted5_wheels_off_tmstz_utc                                 AS diverted_wheels_off_tmstz_utc
     , diverted5_total_ground_time_min                                AS diverted_total_ground_time_min
     , diverted5_longest_ground_time_min                              AS diverted_longest_ground_time_min
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE diverted_ind = 1
  AND diverted5_airport_history_id IS NOT NULL;

-- 4.5. air_oai_facts.airline_flights_scheduled
-- 4.5.1. base data insert (completed flights)
DROP TABLE IF EXISTS air_oai_facts.airline_flights_scheduled;
CREATE TABLE air_oai_facts.airline_flights_scheduled
(
    flight_key                      VARCHAR(255)    NOT NULL
  , flight_date                     DATE
  , airline_oai_code                VARCHAR(50)
  , airline_entity_from_date        DATE
  , airline_entity_id               VARCHAR(50)
  , airline_entity_key              VARCHAR(50)
  , flight_nbr                      VARCHAR(50)
  , flight_count                    VARCHAR(50)
  , tail_nbr                        VARCHAR(50)
  , depart_airport_oai_code         VARCHAR(50)
  , depart_airport_from_date        DATE
  , depart_airport_history_id       VARCHAR(50)
  , depart_airport_history_key      VARCHAR(50)
  , arrive_airport_oai_code         VARCHAR(50)
  , arrive_airport_from_date        DATE
  , arrive_airport_history_id       VARCHAR(50)
  , arrive_airport_history_key      VARCHAR(50)
  , distance_smi                    VARCHAR(50)
  , distance_nmi                    VARCHAR(50)
  , distance_kmt                    VARCHAR(50)
  , distance_group_id               VARCHAR(50)
  , depart_time_block               VARCHAR(50)
  , arrive_time_block               VARCHAR(50)
  , report_depart_tmstz_lcl         TIMESTAMP
  , report_depart_tmstz_utc         TIMESTAMP
  , report_arrive_tmstz_lcl         TIMESTAMP
  , report_arrive_tmstz_utc         TIMESTAMP
  , report_elapsed_time_min         VARCHAR(50)
  , flight_status                   VARCHAR(50)
  , created_by                      VARCHAR(32)
  , created_ts                      TIMESTAMP
  , updated_by                      VARCHAR(32)
  , updated_ts                      TIMESTAMP
);

INSERT INTO air_oai_facts.airline_flights_scheduled
SELECT flight_key
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
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_lcl)
            ELSE report_arrive_tmstz_lcl
       END                                                            AS report_arrive_tmstz_lcl
     , CASE WHEN report_arrive_tmstz_utc <= report_depart_tmstz_utc
            THEN DATEADD(hour, 24, report_arrive_tmstz_utc)
            ELSE report_arrive_tmstz_utc
       END                                                            AS report_arrive_tmstz_utc
     , report_elapsed_time_min
     , flight_status
     , CURRENT_USER::VARCHAR(32)                                      AS created_by
     , GETDATE()::TIMESTAMP                                           AS created_ts
     , NULL::VARCHAR(32)                                              AS updated_by
     , NULL::TIMESTAMP                                                AS updated_ts
FROM air_oai_facts.airline_flight_performance_integrated_mv
WHERE cancelled_ind = 0
  AND diverted_ind  = 0;

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
UPDATE air_oai_facts.airline_flights_scheduled
SET updated_by    = CURRENT_USER
  , updated_ts    = GETDATE()
  , flight_status = a.flight_status
FROM (
    SELECT flight_key, flight_status 
    FROM air_oai_facts.airline_flights_completed
) a
WHERE air_oai_facts.airline_flights_scheduled.flight_key = a.flight_key; --all

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
-- drop view if exists airlines_rs.airline_flights_completed_v;
CREATE OR REPLACE VIEW airlines_rs.airline_flights_completed_v AS
SELECT flight_key, flight_date
     , airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr
     , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
     , distance_smi, distance_nmi, distance_kmt, distance_group_id
     , depart_time_block, arrive_time_block
     , report_depart_tmstz_lcl, report_depart_tmstz_lcl::DATE AS report_depart_date_lcl
     , report_depart_tmstz_utc, report_depart_tmstz_utc::DATE AS report_depart_date_utc
     , report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::DATE AS report_arrive_date_lcl
     , report_arrive_tmstz_utc, report_arrive_tmstz_utc::DATE AS report_arrive_date_utc
     , report_elapsed_time_min, flight_status
     , actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::DATE AS actual_depart_date_lcl
     , actual_depart_tmstz_utc, actual_depart_tmstz_utc::DATE AS actual_depart_date_utc
     , actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::DATE AS actual_arrive_date_lcl
     , actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::DATE AS actual_arrive_date_utc
     , actual_elapsed_time_min
     , wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::DATE AS wheels_off_date_lcl
     , wheels_off_tmstz_utc, wheels_off_tmstz_utc::DATE AS wheels_off_date_utc
     , wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::DATE AS wheels_on_date_lcl
     , wheels_on_tmstz_utc, wheels_on_tmstz_utc::DATE AS wheels_on_date_utc
     , airborne_time_min, taxi_out_min, taxi_in_min
     , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
     , total_ground_time, longest_ground_time
     , airline_delay_min, weather_delay_min, nas_delay_min, security_delay_min, late_aircraft_delay_min
FROM air_oai_facts.airline_flights_completed;

-- drop view if exists airlines_rs.airline_flights_cancelled_v;
CREATE OR REPLACE VIEW airlines_rs.airline_flights_cancelled_v AS
SELECT flight_key, flight_date
     , airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr
     , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
     , distance_smi, distance_nmi, distance_kmt, distance_group_id
     , depart_time_block, arrive_time_block
     , report_depart_tmstz_lcl, report_depart_tmstz_lcl::DATE AS report_depart_date_lcl
     , report_depart_tmstz_utc, report_depart_tmstz_utc::DATE AS report_depart_date_utc
     , report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::DATE AS report_arrive_date_lcl
     , report_arrive_tmstz_utc, report_arrive_tmstz_utc::DATE AS report_arrive_date_utc
     , report_elapsed_time_min, flight_status
     , actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::DATE AS actual_depart_date_lcl
     , actual_depart_tmstz_utc, actual_depart_tmstz_utc::DATE AS actual_depart_date_utc
     , wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::DATE AS wheels_off_date_lcl
     , wheels_off_tmstz_utc, wheels_off_tmstz_utc::DATE AS wheels_off_date_utc
     , taxi_out_min
     , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
     , total_ground_time, longest_ground_time
FROM air_oai_facts.airline_flights_cancelled;

-- drop view if exists airlines_rs.airline_flights_diverted_v;
CREATE OR REPLACE VIEW airlines_rs.airline_flights_diverted_v AS
SELECT flight_key, flight_date
     , airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr
     , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
     , distance_smi, distance_nmi, distance_kmt, distance_group_id
     , depart_time_block, arrive_time_block
     , report_depart_tmstz_lcl, report_depart_tmstz_lcl::DATE AS report_depart_date_lcl
     , report_depart_tmstz_utc, report_depart_tmstz_utc::DATE AS report_depart_date_utc
     , report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::DATE AS report_arrive_date_lcl
     , report_arrive_tmstz_utc, report_arrive_tmstz_utc::DATE AS report_arrive_date_utc
     , report_elapsed_time_min, flight_status
     , actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::DATE AS actual_depart_date_lcl
     , actual_depart_tmstz_utc, actual_depart_tmstz_utc::DATE AS actual_depart_date_utc
     , actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::DATE AS actual_arrive_date_lcl
     , actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::DATE AS actual_arrive_date_utc
     , actual_elapsed_time_min
     , wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::DATE AS wheels_off_date_lcl
     , wheels_off_tmstz_utc, wheels_off_tmstz_utc::DATE AS wheels_off_date_utc
     , wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::DATE AS wheels_on_date_lcl
     , wheels_on_tmstz_utc, wheels_on_tmstz_utc::DATE AS wheels_on_date_utc
     , airborne_time_min, taxi_out_min, taxi_in_min
     , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
     , total_ground_time, longest_ground_time
FROM air_oai_facts.airline_flights_diverted;

-- drop view if exists airlines_rs.airline_flights_diverted_legs_v:
CREATE OR REPLACE VIEW airlines_rs.airline_flights_diverted_legs_v AS
SELECT flight_key, diversion_nbr, flight_date
     , airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr
     , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , original_arrive_airport_oai_code, original_arrive_airport_from_date
     , original_arrive_airport_history_id, original_arrive_airport_history_key
     , diverted_airport_oai_code, diverted_airport_from_date
     , diverted_airport_history_id, diverted_airport_history_key
     , diverted_tail_nbr
     , diverted_wheels_on_tmstz_lcl, diverted_wheels_on_tmstz_utc
     , diverted_wheels_off_tmstz_lcl, diverted_wheels_off_tmstz_utc
     , diverted_total_ground_time_min, diverted_longest_ground_time_min
FROM air_oai_facts.airline_flights_diverted_legs;

-- drop view if exists airlines_rs.airline_flights_scheduled_v;
CREATE OR REPLACE VIEW airlines_rs.airline_flights_scheduled_v AS
SELECT flight_key, flight_date
     , airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr
     , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
     , distance_smi, distance_nmi, distance_kmt, distance_group_id
     , depart_time_block, arrive_time_block
     , report_depart_tmstz_lcl, report_depart_tmstz_lcl::DATE AS report_depart_date_lcl
     , report_depart_tmstz_utc, report_depart_tmstz_utc::DATE AS report_depart_date_utc
     , report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::DATE AS report_arrive_date_lcl
     , report_arrive_tmstz_utc, report_arrive_tmstz_utc::DATE AS report_arrive_date_utc
     , report_elapsed_time_min
FROM air_oai_facts.airline_flights_scheduled;