-- OTP (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline On-Time Performance Data Database > Reporting Carrier On-Time Performance (1987-present)
-- https://transtats.bts.gov/Tables.asp?QO_VQ=EFD&QO_anzr=Nv4yv0r%FDb0-gvzr%FDcr4s14zn0pr%FDQn6n&QO_fu146_anzr=b0-gvzr

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. extraction stage (S3 CSV to multipart otp_raw_extract/*.parquet on local NVMe)
-- 2. integration stage (dimension joins to multipart otp_integrated_hub/*.parquet)
-- 3. slice final target tables directly from multipart otp_integrated_hub/*.parquet
--  3.1. create and load air_oai_facts.airline_flights_completed
--  3.2. create and load air_oai_facts.airline_flights_cancelled
--  3.3. create and load air_oai_facts.airline_flights_diverted
--  3.4. create and load air_oai_facts.airline_flights_diverted_legs
--  3.5. create and load air_oai_facts.airline_flights_scheduled
-- 4. add table constraints
-- 5. create presentation layer views
----------------------------------------------------

-- 1. extraction stage
copy (
    select 
          year_nbr::smallint as year_nbr
        , month_nbr::smallint as month_nbr
        , flight_date::date as flight_date
        , airline_oai_code::varchar(3) as airline_oai_code
        , airline_usdot_id::integer as airline_usdot_id
        , nullif(trim(tail_nbr), '')::varchar(10) as tail_nbr
        , lpad(flight_nbr::varchar, 4, '0')::char(4) as flight_nbr
        , coalesce(flight_count::smallint, 1) as flight_count
        , depart_airport_oai_id::integer as depart_airport_oai_id
        , depart_airport_oai_code::char(3) as depart_airport_oai_code
        , arrive_airport_oai_id::integer as arrive_airport_oai_id
        , arrive_airport_oai_code::char(3) as arrive_airport_oai_code
        , distance_smi::smallint as distance_smi
        , distance_group_id::smallint as distance_group_id
        , depart_time_block::varchar(10) as depart_time_block
        , arrive_time_block::varchar(10) as arrive_time_block
        , nullif(trim(report_depart_time_lcl::varchar), '')::char(4) as report_depart_time_lcl
        , nullif(trim(actual_depart_time_lcl::varchar), '')::char(4) as actual_depart_time_lcl
        , nullif(trim(report_arrive_time_lcl::varchar), '')::char(4) as report_arrive_time_lcl
        , nullif(trim(actual_arrive_time_lcl::varchar), '')::char(4) as actual_arrive_time_lcl
        , nullif(trim(wheels_off_time_lcl::varchar), '')::char(4) as wheels_off_time_lcl
        , nullif(trim(wheels_on_time_lcl::varchar), '')::char(4) as wheels_on_time_lcl
        , nullif(trim(first_gate_depart_time::varchar), '')::char(4) as first_gate_depart_time
        , report_elapsed_time_min::integer as report_elapsed_time_min
        , actual_elapsed_time_min::integer as actual_elapsed_time_min
        , airborne_time_min::integer as airborne_time_min
        , taxi_out_min::integer as taxi_out_min
        , taxi_in_min::integer as taxi_in_min
        , nullif(trim(total_ground_time::varchar), '')::integer as total_ground_time
        , nullif(trim(longest_ground_time::varchar), '')::integer as longest_ground_time
        , coalesce(cancelled_ind::smallint, 0) as cancelled_ind
        , nullif(trim(cancellation_code), '')::varchar(25) as cancellation_code
        , coalesce(diverted_ind::smallint, 0) as diverted_ind
        , airline_delay_min::smallint as airline_delay_min
        , weather_delay_min::smallint as weather_delay_min
        , nas_delay_min::smallint as nas_delay_min
        , security_delay_min::smallint as security_delay_min
        , late_aircraft_delay_min::smallint as late_aircraft_delay_min
        -- diverted legs 1..5
        , diverted1_airport_oai_code::char(3) as diverted1_airport_oai_code
        , nullif(trim(diverted1_tail_nbr), '')::varchar(10) as diverted1_tail_nbr
        , nullif(trim(diverted1_wheels_on_time_lcl::varchar), '')::char(4) as diverted1_wheels_on_time_lcl
        , nullif(trim(diverted1_wheels_off_time_lcl::varchar), '')::char(4) as diverted1_wheels_off_time_lcl
        , diverted1_total_ground_time_min::smallint as diverted1_total_ground_time_min
        , diverted1_longest_ground_time_min::smallint as diverted1_longest_ground_time_min

        , diverted2_airport_oai_code::char(3) as diverted2_airport_oai_code
        , nullif(trim(diverted2_tail_nbr), '')::varchar(10) as diverted2_tail_nbr
        , nullif(trim(diverted2_wheels_on_time_lcl::varchar), '')::char(4) as diverted2_wheels_on_time_lcl
        , nullif(trim(diverted2_wheels_off_time_lcl::varchar), '')::char(4) as diverted2_wheels_off_time_lcl
        , diverted2_total_ground_time_min::smallint as diverted2_total_ground_time_min
        , diverted2_longest_ground_time_min::smallint as diverted2_longest_ground_time_min

        , diverted3_airport_oai_code::char(3) as diverted3_airport_oai_code
        , nullif(trim(diverted3_tail_nbr), '')::varchar(10) as diverted3_tail_nbr
        , nullif(trim(diverted3_wheels_on_time_lcl::varchar), '')::char(4) as diverted3_wheels_on_time_lcl
        , nullif(trim(diverted3_wheels_off_time_lcl::varchar), '')::char(4) as diverted3_wheels_off_time_lcl
        , diverted3_total_ground_time_min::smallint as diverted3_total_ground_time_min
        , diverted3_longest_ground_time_min::smallint as diverted3_longest_ground_time_min

        , diverted4_airport_oai_code::char(3) as diverted4_airport_oai_code
        , nullif(trim(diverted4_tail_nbr), '')::varchar(10) as diverted4_tail_nbr
        , nullif(trim(diverted4_wheels_on_time_lcl::varchar), '')::char(4) as diverted4_wheels_on_time_lcl
        , nullif(trim(diverted4_wheels_off_time_lcl::varchar), '')::char(4) as diverted4_wheels_off_time_lcl
        , diverted4_total_ground_time_min::smallint as diverted4_total_ground_time_min
        , diverted4_longest_ground_time_min::smallint as diverted4_longest_ground_time_min

        , diverted5_airport_oai_code::char(3) as diverted5_airport_oai_code
        , nullif(trim(diverted5_tail_nbr), '')::varchar(10) as diverted5_tail_nbr
        , nullif(trim(diverted5_wheels_on_time_lcl::varchar), '')::char(4) as diverted5_wheels_on_time_lcl
        , nullif(trim(diverted5_wheels_off_time_lcl::varchar), '')::char(4) as diverted5_wheels_off_time_lcl
        , diverted5_total_ground_time_min::smallint as diverted5_total_ground_time_min
        , diverted5_longest_ground_time_min::smallint as diverted5_longest_ground_time_min
    from read_csv('s3://src-aviation/OTP/CSV/*.csv.gz', union_by_name=true)
) to 'otp_raw_extract' (format 'parquet', compression 'zstd', per_thread_output true);

-- 2. integration stage (resolve keys, compute timestamps, and write core integrated parquet hub)
copy (
    with raw_local_parquet as (
        select * from read_parquet('otp_raw_extract/*.parquet')
    )
    select 
          md5(fp.airline_oai_code || '|' || fp.flight_nbr || '|' || fp.flight_date::varchar || '|' || fp.depart_airport_oai_code)::char(32) as flight_key
        , fp.flight_date
        , fp.airline_oai_code
        , ae.source_from_date as airline_entity_from_date
        , ae.airline_entity_id
        , ae.airline_entity_key
        , fp.flight_nbr
        , fp.flight_count
        , fp.tail_nbr
        , fp.depart_airport_oai_code
        , a.effective_from_date as depart_airport_from_date
        , a.airport_history_id as depart_airport_history_id
        , a.airport_history_key as depart_airport_history_key
        , fp.arrive_airport_oai_code
        , b.effective_from_date as arrive_airport_from_date
        , b.airport_history_id as arrive_airport_history_id
        , b.airport_history_key as arrive_airport_history_key
        , fp.distance_smi
        , (fp.distance_smi / 1.1508)::numeric(10,2) as distance_nmi
        , (fp.distance_smi * 1.60934)::numeric(10,2) as distance_kmt
        , fp.distance_group_id
        , fp.depart_time_block
        , fp.arrive_time_block
        
        -- localized execution timestamps
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.report_depart_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.report_depart_time_lcl, 4, '0'), 3, 2) as timestamp) as report_depart_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.report_arrive_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.report_arrive_time_lcl, 4, '0'), 3, 2) as timestamp) as report_arrive_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.actual_depart_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.actual_depart_time_lcl, 4, '0'), 3, 2) as timestamp) as actual_depart_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.actual_arrive_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.actual_arrive_time_lcl, 4, '0'), 3, 2) as timestamp) as actual_arrive_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as wheels_off_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as wheels_on_tmstz_lcl
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.first_gate_depart_time, 4, '0'), 1, 2) || ':' || substring(lpad(fp.first_gate_depart_time, 4, '0'), 3, 2) as timestamp) as first_gate_depart_tmstz_lcl
        
        -- native timeline serialization over timezone layers to utc arrays
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.report_depart_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.report_depart_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone a.time_zone_name) at time zone 'UTC' as report_depart_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.report_arrive_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.report_arrive_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone b.time_zone_name) at time zone 'UTC' as report_arrive_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.actual_depart_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.actual_depart_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone a.time_zone_name) at time zone 'UTC' as actual_depart_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.actual_arrive_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.actual_arrive_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone b.time_zone_name) at time zone 'UTC' as actual_arrive_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone a.time_zone_name) at time zone 'UTC' as wheels_off_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone b.time_zone_name) at time zone 'UTC' as wheels_on_tmstz_utc
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.first_gate_depart_time, 4, '0'), 1, 2) || ':' || substring(lpad(fp.first_gate_depart_time, 4, '0'), 3, 2) as timestamp) at time zone a.time_zone_name) at time zone 'UTC' as first_gate_depart_tmstz_utc
        
        , fp.report_elapsed_time_min
        , fp.actual_elapsed_time_min
        , fp.airborne_time_min
        , fp.taxi_out_min
        , fp.taxi_in_min
        , fp.total_ground_time
        , fp.longest_ground_time
        , fp.airline_delay_min
        , fp.weather_delay_min
        , fp.nas_delay_min
        , fp.security_delay_min
        , fp.late_aircraft_delay_min
        
        , fp.cancelled_ind
        , fp.cancellation_code
        , fp.diverted_ind
        , case 
            when fp.cancelled_ind = 1 then 'cancelled'
            when fp.diverted_ind = 1 then 'diverted'
            when fp.airline_delay_min is not null then 'arrived_delayed'
            else 'arrived_on_time'
          end::varchar(25) as flight_status

        -- structural unpivot parameters for active flight legs (d1..d5)
        , fp.diverted1_airport_oai_code
        , d1.effective_from_date as diverted1_airport_from_date
        , d1.airport_history_id as diverted1_airport_history_id
        , d1.airport_history_key as diverted1_airport_history_key
        , fp.diverted1_tail_nbr
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted1_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted1_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted1_wheels_on_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted1_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted1_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d1.time_zone_name) at time zone 'UTC' as diverted1_wheels_on_tmstz_utc
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted1_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted1_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted1_wheels_off_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted1_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted1_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d1.time_zone_name) at time zone 'UTC' as diverted1_wheels_off_tmstz_utc
        , fp.diverted1_total_ground_time_min
        , fp.diverted1_longest_ground_time_min

        , fp.diverted2_airport_oai_code
        , d2.effective_from_date as diverted2_airport_from_date
        , d2.airport_history_id as diverted2_airport_history_id
        , d2.airport_history_key as diverted2_airport_history_key
        , fp.diverted2_tail_nbr
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted2_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted2_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted2_wheels_on_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted2_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted2_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d2.time_zone_name) at time zone 'UTC' as diverted2_wheels_on_tmstz_utc
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted2_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted2_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted2_wheels_off_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted2_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted2_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d2.time_zone_name) at time zone 'UTC' as diverted2_wheels_off_tmstz_utc
        , fp.diverted2_total_ground_time_min
        , fp.diverted2_longest_ground_time_min

        , fp.diverted3_airport_oai_code
        , d3.effective_from_date as diverted3_airport_from_date
        , d3.airport_history_id as diverted3_airport_history_id
        , d3.airport_history_key as diverted3_airport_history_key
        , fp.diverted3_tail_nbr
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted3_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted3_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted3_wheels_on_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted3_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted3_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d3.time_zone_name) at time zone 'UTC' as diverted3_wheels_on_tmstz_utc
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted3_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted3_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted3_wheels_off_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted3_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted3_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d3.time_zone_name) at time zone 'UTC' as diverted3_wheels_off_tmstz_utc
        , fp.diverted3_total_ground_time_min
        , fp.diverted3_longest_ground_time_min

        , fp.diverted4_airport_oai_code
        , d4.effective_from_date as diverted4_airport_from_date
        , d4.airport_history_id as diverted4_airport_history_id
        , d4.airport_history_key as diverted4_airport_history_key
        , fp.diverted4_tail_nbr
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted4_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted4_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted4_wheels_on_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted4_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted4_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d4.time_zone_name) at time zone 'UTC' as diverted4_wheels_on_tmstz_utc
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted4_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted4_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted4_wheels_off_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted4_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted4_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d4.time_zone_name) at time zone 'UTC' as diverted4_wheels_off_tmstz_utc
        , fp.diverted4_total_ground_time_min
        , fp.diverted4_longest_ground_time_min

        , fp.diverted5_airport_oai_code
        , d5.effective_from_date as diverted5_airport_from_date
        , d5.airport_history_id as diverted5_airport_history_id
        , d5.airport_history_key as diverted5_airport_history_key
        , fp.diverted5_tail_nbr
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted5_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted5_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted5_wheels_on_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted5_wheels_on_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted5_wheels_on_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d5.time_zone_name) at time zone 'UTC' as diverted5_wheels_on_tmstz_utc
        , try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted5_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted5_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) as diverted5_wheels_off_tmstz_lcl
        , (try_cast(fp.flight_date::varchar || ' ' || substring(lpad(fp.diverted5_wheels_off_time_lcl, 4, '0'), 1, 2) || ':' || substring(lpad(fp.diverted5_wheels_off_time_lcl, 4, '0'), 3, 2) as timestamp) at time zone d5.time_zone_name) at time zone 'UTC' as diverted5_wheels_off_tmstz_utc
        , fp.diverted5_total_ground_time_min
        , fp.diverted5_longest_ground_time_min
    from raw_local_parquet fp
    left join air_oai_dims.airline_entities ae 
      on fp.airline_oai_code = ae.airline_oai_code 
     and fp.flight_date between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
    left join air_oai_dims.airport_history a 
      on fp.depart_airport_oai_code = a.airport_oai_code 
     and fp.flight_date between a.effective_from_date and coalesce(a.effective_thru_date, current_date)
    left join air_oai_dims.airport_history b 
      on fp.arrive_airport_oai_code = b.airport_oai_code 
     and fp.flight_date between b.effective_from_date and coalesce(b.effective_thru_date, current_date)
    left join air_oai_dims.airport_history d1 
      on fp.diverted1_airport_oai_code = d1.airport_oai_code 
     and fp.flight_date between d1.effective_from_date and coalesce(d1.effective_thru_date, current_date)
    left join air_oai_dims.airport_history d2 
      on fp.diverted2_airport_oai_code = d2.airport_oai_code 
     and fp.flight_date between d2.effective_from_date and coalesce(d2.effective_thru_date, current_date)
    left join air_oai_dims.airport_history d3 
      on fp.diverted3_airport_oai_code = d3.airport_oai_code 
     and fp.flight_date between d3.effective_from_date and coalesce(d3.effective_thru_date, current_date)
    left join air_oai_dims.airport_history d4 
      on fp.diverted4_airport_oai_code = d4.airport_oai_code 
     and fp.flight_date between d4.effective_from_date and coalesce(d4.effective_thru_date, current_date)
    left join air_oai_dims.airport_history d5 
      on fp.diverted5_airport_oai_code = d5.airport_oai_code 
     and fp.flight_date between d5.effective_from_date and coalesce(d5.effective_thru_date, current_date)
) to 'otp_integrated_hub' (format 'parquet', compression 'zstd', per_thread_output true);

-- 3. slice final target tables directly from the integrated hub
-- 3.1. airline_flights_completed
drop table if exists air_oai_facts.airline_flights_completed;
create table air_oai_facts.airline_flights_completed as
select 
      flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_lcl + interval 24 hour else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_utc + interval 24 hour else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
    , report_elapsed_time_min
    , case when airline_delay_min is not null then 'completed-delayed' else 'completed-on-time' end::varchar(25) as flight_status
    , actual_depart_tmstz_lcl, actual_depart_tmstz_utc
    , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc then actual_arrive_tmstz_lcl + interval 24 hour else actual_arrive_tmstz_lcl end as actual_arrive_tmstz_lcl
    , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc then actual_arrive_tmstz_utc + interval 24 hour else actual_arrive_tmstz_utc end as actual_arrive_tmstz_utc
    , actual_elapsed_time_min
    , wheels_off_tmstz_lcl, wheels_off_tmstz_utc
    , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc then wheels_on_tmstz_lcl + interval 24 hour else wheels_on_tmstz_lcl end as wheels_on_tmstz_lcl
    , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc then wheels_on_tmstz_utc + interval 24 hour else wheels_on_tmstz_utc end as wheels_on_tmstz_utc
    , airborne_time_min, taxi_out_min, taxi_in_min
    , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
    , total_ground_time, longest_ground_time
    , airline_delay_min, weather_delay_min, nas_delay_min, security_delay_min, late_aircraft_delay_min
    , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts
    , null::varchar(32) as updated_by, null::timestamp as updated_ts
from read_parquet('otp_integrated_hub/*.parquet')
where cancelled_ind = 0 and diverted_ind = 0;


-- 3.2. airline_flights_cancelled
drop table if exists air_oai_facts.airline_flights_cancelled;
create table air_oai_facts.airline_flights_cancelled as
select 
      flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_lcl + interval 24 hour else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_utc + interval 24 hour else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , actual_depart_tmstz_lcl, actual_depart_tmstz_utc
    , wheels_off_tmstz_lcl, wheels_off_tmstz_utc
    , taxi_out_min
    , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
    , total_ground_time, longest_ground_time
    , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts
    , null::varchar(32) as updated_by, null::timestamp as updated_ts
from read_parquet('otp_integrated_hub/*.parquet')
where cancelled_ind = 1;


-- 3.3. airline_flights_diverted
drop table if exists air_oai_facts.airline_flights_diverted;
create table air_oai_facts.airline_flights_diverted as
select 
      flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_lcl + interval 24 hour else report_arrive_tmstz_lcl end as report_arrive_tmstz_lcl
    , case when report_arrive_tmstz_utc <= report_depart_tmstz_utc then report_arrive_tmstz_utc + interval 24 hour else report_arrive_tmstz_utc end as report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , actual_depart_tmstz_lcl, actual_depart_tmstz_utc
    , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc then actual_arrive_tmstz_lcl + interval 24 hour else actual_arrive_tmstz_lcl end as actual_arrive_tmstz_lcl
    , case when actual_arrive_tmstz_utc <= actual_depart_tmstz_utc then actual_arrive_tmstz_utc + interval 24 hour else actual_arrive_tmstz_utc end as actual_arrive_tmstz_utc
    , actual_elapsed_time_min
    , wheels_off_tmstz_lcl, wheels_off_tmstz_utc
    , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc then wheels_on_tmstz_lcl + interval 24 hour else wheels_on_tmstz_lcl end as wheels_on_tmstz_lcl
    , case when wheels_on_tmstz_utc <= wheels_off_tmstz_utc then wheels_on_tmstz_utc + interval 24 hour else wheels_on_tmstz_utc end as wheels_on_tmstz_utc
    , airborne_time_min, taxi_out_min, taxi_in_min
    , first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
    , total_ground_time, longest_ground_time
    , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts
    , null::varchar(32) as updated_by, null::timestamp as updated_ts
from read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1;


-- 3.4. airline_flights_diverted_legs
drop table if exists air_oai_facts.airline_flights_diverted_legs;
create table air_oai_facts.airline_flights_diverted_legs as
SELECT flight_key, 1::smallint as diversion_nbr, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code as original_arrive_airport_oai_code, arrive_airport_from_date as original_arrive_airport_from_date, arrive_airport_history_id as original_arrive_airport_history_id, arrive_airport_history_key as original_arrive_airport_history_key
     , diverted1_airport_oai_code as diverted_airport_oai_code, diverted1_airport_from_date as diverted_airport_from_date
     , diverted1_airport_history_id as diverted_airport_history_id, diverted1_airport_history_key as diverted_airport_history_key
     , diverted1_tail_nbr as diverted_tail_nbr
     , diverted1_wheels_on_tmstz_lcl as diverted_wheels_on_tmstz_lcl
     , diverted1_wheels_on_tmstz_utc as diverted_wheels_on_tmstz_utc
     , diverted1_wheels_off_tmstz_lcl as diverted_wheels_off_tmstz_lcl
     , diverted1_wheels_off_tmstz_utc as diverted_wheels_off_tmstz_utc
     , diverted1_total_ground_time_min as diverted_total_ground_time_min, diverted1_longest_ground_time_min as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts, null::varchar(32) as updated_by, null::timestamp as updated_ts 
FROM read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1 and diverted1_airport_history_id is not null
union all
SELECT flight_key, 2::smallint as diversion_nbr, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code as original_arrive_airport_oai_code, arrive_airport_from_date as original_arrive_airport_from_date, arrive_airport_history_id as original_arrive_airport_history_id, arrive_airport_history_key as original_arrive_airport_history_key
     , diverted2_airport_oai_code as diverted_airport_oai_code, diverted2_airport_from_date as diverted_airport_from_date
     , diverted2_airport_history_id as diverted_airport_history_id, diverted2_airport_history_key as diverted_airport_history_key
     , diverted2_tail_nbr as diverted_tail_nbr
     , diverted2_wheels_on_tmstz_lcl as diverted_wheels_on_tmstz_lcl
     , diverted2_wheels_on_tmstz_utc as diverted_wheels_on_tmstz_utc
     , diverted2_wheels_off_tmstz_lcl as diverted_wheels_off_tmstz_lcl
     , diverted2_wheels_off_tmstz_utc as diverted_wheels_off_tmstz_utc
     , diverted2_total_ground_time_min as diverted_total_ground_time_min, diverted2_longest_ground_time_min as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts, null::varchar(32) as updated_by, null::timestamp as updated_ts 
FROM read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1 and diverted2_airport_history_id is not null
union all
SELECT flight_key, 3::smallint as diversion_nbr, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code as original_arrive_airport_oai_code, arrive_airport_from_date as original_arrive_airport_from_date, arrive_airport_history_id as original_arrive_airport_history_id, arrive_airport_history_key as original_arrive_airport_history_key
     , diverted3_airport_oai_code as diverted_airport_oai_code, diverted3_airport_from_date as diverted_airport_from_date
     , diverted3_airport_history_id as diverted_airport_history_id, diverted3_airport_history_key as diverted_airport_history_key
     , diverted3_tail_nbr as diverted_tail_nbr
     , diverted3_wheels_on_tmstz_lcl as diverted_wheels_on_tmstz_lcl
     , diverted3_wheels_on_tmstz_utc as diverted_wheels_on_tmstz_utc
     , diverted3_wheels_off_tmstz_lcl as diverted_wheels_off_tmstz_lcl
     , diverted3_wheels_off_tmstz_utc as diverted_wheels_off_tmstz_utc
     , diverted3_total_ground_time_min as diverted_total_ground_time_min, diverted3_longest_ground_time_min as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts, null::varchar(32) as updated_by, null::timestamp as updated_ts 
FROM read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1 and diverted3_airport_history_id is not null
union all
SELECT flight_key, 4::smallint as diversion_nbr, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code as original_arrive_airport_oai_code, arrive_airport_from_date as original_arrive_airport_from_date, arrive_airport_history_id as original_arrive_airport_history_id, arrive_airport_history_key as original_arrive_airport_history_key
     , diverted4_airport_oai_code as diverted_airport_oai_code, diverted4_airport_from_date as diverted_airport_from_date
     , diverted4_airport_history_id as diverted_airport_history_id, diverted4_airport_history_key as diverted_airport_history_key
     , diverted4_tail_nbr as diverted_tail_nbr
     , diverted4_wheels_on_tmstz_lcl as diverted_wheels_on_tmstz_lcl
     , diverted4_wheels_on_tmstz_utc as diverted_wheels_on_tmstz_utc
     , diverted4_wheels_off_tmstz_lcl as diverted_wheels_off_tmstz_lcl
     , diverted4_wheels_off_tmstz_utc as diverted_wheels_off_tmstz_utc
     , diverted4_total_ground_time_min as diverted_total_ground_time_min, diverted4_longest_ground_time_min as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts, null::varchar(32) as updated_by, null::timestamp as updated_ts 
FROM read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1 and diverted4_airport_history_id is not null
union all
SELECT flight_key, 5::smallint as diversion_nbr, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
     , flight_nbr, flight_count, tail_nbr, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
     , arrive_airport_oai_code as original_arrive_airport_oai_code, arrive_airport_from_date as original_arrive_airport_from_date, arrive_airport_history_id as original_arrive_airport_history_id, arrive_airport_history_key as original_arrive_airport_history_key
     , diverted5_airport_oai_code as diverted_airport_oai_code, diverted5_airport_from_date as diverted_airport_from_date
     , diverted5_airport_history_id as diverted_airport_history_id, diverted5_airport_history_key as diverted_airport_history_key
     , diverted5_tail_nbr as diverted_tail_nbr
     , diverted5_wheels_on_tmstz_lcl as diverted_wheels_on_tmstz_lcl
     , diverted5_wheels_on_tmstz_utc as diverted_wheels_on_tmstz_utc
     , diverted5_wheels_off_tmstz_lcl as diverted_wheels_off_tmstz_lcl
     , diverted5_wheels_off_tmstz_utc as diverted_wheels_off_tmstz_utc
     , diverted5_total_ground_time_min as diverted_total_ground_time_min, diverted5_longest_ground_time_min as diverted_longest_ground_time_min
     , current_user::varchar(32) as created_by, current_timestamp::timestamp as created_ts, null::varchar(32) as updated_by, null::timestamp as updated_ts 
FROM read_parquet('otp_integrated_hub/*.parquet')
where diverted_ind = 1 and diverted5_airport_history_id is not null;


-- 3.5. airline_flights_scheduled
drop table if exists air_oai_facts.airline_flights_scheduled;
create table air_oai_facts.airline_flights_scheduled as
select flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc, report_arrive_tmstz_lcl, report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , created_by, created_ts, updated_by, updated_ts
from air_oai_facts.airline_flights_completed
union all
select flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc, report_arrive_tmstz_lcl, report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , created_by, created_ts, updated_by, updated_ts
from air_oai_facts.airline_flights_cancelled
union all
select flight_key, flight_date, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
    , flight_nbr, flight_count, tail_nbr
    , depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
    , arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
    , distance_smi, distance_nmi, distance_kmt, distance_group_id
    , depart_time_block, arrive_time_block
    , report_depart_tmstz_lcl, report_depart_tmstz_utc, report_arrive_tmstz_lcl, report_arrive_tmstz_utc
    , report_elapsed_time_min, flight_status
    , created_by, created_ts, updated_by, updated_ts
from air_oai_facts.airline_flights_diverted;


-- 4. add table constraints
-- airline_flights_completed
alter table air_oai_facts.airline_flights_completed alter flight_key set not null;
alter table air_oai_facts.airline_flights_completed alter flight_date set not null;
alter table air_oai_facts.airline_flights_completed alter airline_oai_code set not null;
alter table air_oai_facts.airline_flights_completed alter airline_entity_from_date set not null;
alter table air_oai_facts.airline_flights_completed alter airline_entity_id set not null;
alter table air_oai_facts.airline_flights_completed alter airline_entity_key set not null;
alter table air_oai_facts.airline_flights_completed alter flight_nbr set not null;
alter table air_oai_facts.airline_flights_completed alter flight_count set not null;
alter table air_oai_facts.airline_flights_completed alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_completed alter depart_airport_from_date set not null;
alter table air_oai_facts.airline_flights_completed alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_flights_completed alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_flights_completed alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_completed alter arrive_airport_from_date set not null;
alter table air_oai_facts.airline_flights_completed alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_flights_completed alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_flights_completed alter flight_status set not null;
alter table air_oai_facts.airline_flights_completed alter created_by set not null;
alter table air_oai_facts.airline_flights_completed alter created_ts set not null;
alter table air_oai_facts.airline_flights_completed add constraint airline_flights_completed_pk primary key (flight_key);

-- airline_flights_cancelled
alter table air_oai_facts.airline_flights_cancelled alter flight_key set not null;
alter table air_oai_facts.airline_flights_cancelled alter flight_date set not null;
alter table air_oai_facts.airline_flights_cancelled alter airline_oai_code set not null;
alter table air_oai_facts.airline_flights_cancelled alter airline_entity_from_date set not null;
alter table air_oai_facts.airline_flights_cancelled alter airline_entity_id set not null;
alter table air_oai_facts.airline_flights_cancelled alter airline_entity_key set not null;
alter table air_oai_facts.airline_flights_cancelled alter flight_nbr set not null;
alter table air_oai_facts.airline_flights_cancelled alter flight_count set not null;
alter table air_oai_facts.airline_flights_cancelled alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_cancelled alter depart_airport_from_date set not null;
alter table air_oai_facts.airline_flights_cancelled alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_flights_cancelled alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_flights_cancelled alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_cancelled alter arrive_airport_from_date set not null;
alter table air_oai_facts.airline_flights_cancelled alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_flights_cancelled alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_flights_cancelled alter flight_status set not null;
alter table air_oai_facts.airline_flights_cancelled alter created_by set not null;
alter table air_oai_facts.airline_flights_cancelled alter created_ts set not null;
alter table air_oai_facts.airline_flights_cancelled add constraint airline_flights_cancelled_pk primary key (flight_key);

-- airline_flights_diverted
alter table air_oai_facts.airline_flights_diverted alter flight_key set not null;
alter table air_oai_facts.airline_flights_diverted alter flight_date set not null;
alter table air_oai_facts.airline_flights_diverted alter airline_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted alter airline_entity_from_date set not null;
alter table air_oai_facts.airline_flights_diverted alter airline_entity_id set not null;
alter table air_oai_facts.airline_flights_diverted alter airline_entity_key set not null;
alter table air_oai_facts.airline_flights_diverted alter flight_nbr set not null;
alter table air_oai_facts.airline_flights_diverted alter flight_count set not null;
alter table air_oai_facts.airline_flights_diverted alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted alter depart_airport_from_date set not null;
alter table air_oai_facts.airline_flights_diverted alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_flights_diverted alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_flights_diverted alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted alter arrive_airport_from_date set not null;
alter table air_oai_facts.airline_flights_diverted alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_flights_diverted alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_flights_diverted alter flight_status set not null;
alter table air_oai_facts.airline_flights_diverted alter created_by set not null;
alter table air_oai_facts.airline_flights_diverted alter created_ts set not null;
alter table air_oai_facts.airline_flights_diverted add constraint airline_flights_diverted_pk primary key (flight_key);

-- airline_flights_diverted_legs
alter table air_oai_facts.airline_flights_diverted_legs alter flight_key set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter diversion_nbr set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter flight_date set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter airline_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter airline_entity_from_date set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter airline_entity_id set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter airline_entity_key set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter flight_nbr set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter flight_count set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter depart_airport_from_date set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter original_arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter original_arrive_airport_from_date set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter original_arrive_airport_history_id set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter original_arrive_airport_history_key set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter diverted_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter diverted_airport_from_date set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter diverted_airport_history_id set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter diverted_airport_history_key set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter created_by set not null;
alter table air_oai_facts.airline_flights_diverted_legs alter created_ts set not null;
alter table air_oai_facts.airline_flights_diverted_legs add constraint airline_flights_diverted_legs_pk primary key (flight_key, diversion_nbr);

-- airline_flights_scheduled
alter table air_oai_facts.airline_flights_scheduled alter flight_key set not null;
alter table air_oai_facts.airline_flights_scheduled alter flight_date set not null;
alter table air_oai_facts.airline_flights_scheduled alter airline_oai_code set not null;
alter table air_oai_facts.airline_flights_scheduled alter airline_entity_from_date set not null;
alter table air_oai_facts.airline_flights_scheduled alter airline_entity_id set not null;
alter table air_oai_facts.airline_flights_scheduled alter airline_entity_key set not null;
alter table air_oai_facts.airline_flights_scheduled alter flight_nbr set not null;
alter table air_oai_facts.airline_flights_scheduled alter flight_count set not null;
alter table air_oai_facts.airline_flights_scheduled alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_scheduled alter depart_airport_from_date set not null;
alter table air_oai_facts.airline_flights_scheduled alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_flights_scheduled alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_flights_scheduled alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_flights_scheduled alter arrive_airport_from_date set not null;
alter table air_oai_facts.airline_flights_scheduled alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_flights_scheduled alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_flights_scheduled alter flight_status set not null;
alter table air_oai_facts.airline_flights_scheduled alter created_by set not null;
alter table air_oai_facts.airline_flights_scheduled alter created_ts set not null;
alter table air_oai_facts.airline_flights_scheduled add constraint airline_flights_scheduled_pk primary key (flight_key);


-- 5. create presentation layer views
-- drop view if exists airlines_ddb.airline_flights_completed_v;
create or replace view airlines_ddb.airline_flights_completed_v as
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

-- drop view if exists airlines_ddb.airline_flights_cancelled_v;
create or replace view airlines_ddb.airline_flights_cancelled_v as
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

-- drop view if exists airlines_ddb.airline_flights_diverted_v;
create or replace view airlines_ddb.airline_flights_diverted_v as
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

-- drop view if exists airlines_ddb.airline_flights_diverted_legs_v;
create or replace view airlines_ddb.airline_flights_diverted_legs_v as
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

-- drop view if exists airlines_ddb.airline_flights_scheduled_v;
create or replace view airlines_ddb.airline_flights_scheduled_v as
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
