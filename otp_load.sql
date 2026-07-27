-- OTP (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline On-Time Performance Data Database > Reporting Carrier On-Time Performance (1987-present)
-- https://transtats.bts.gov/Tables.asp?QO_VQ=EFD&QO_anzr=Nv4yv0r%FDb0-gvzr%FDcr4s14zn0pr%FDQn6n&QO_fu146_anzr=b0-gvzr

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. extraction and integration stage 
--  1.1. position-Based Multi-File CSV Streaming & Midnight Encodings
--  1.2. multi-Dimensional Range Interval Asymmetric Lookups
--  1.3. vectorized String Tokenization & Temporal Additions (+1 Day Loops)
--  1.4. final projection with metric serialization
-- 2. slice final target tables directly from multipart otp_integrated_hub/*.parquet
--  2.1. create and load air_oai_facts.airline_flights_completed
--  2.2. create and load air_oai_facts.airline_flights_cancelled
--  2.3. create and load air_oai_facts.airline_flights_diverted
--  2.4. create and load air_oai_facts.airline_flights_diverted_legs
--  2.5. create and load air_oai_facts.airline_flights_scheduled
-- 3. add table constraints
-- 4. create presentation layer views
----------------------------------------------------

-- 1. extraction and integration stage
DROP TABLE IF EXISTS air_oai_facts.airline_flight_performance;

CREATE TABLE air_oai_facts.airline_flight_performance AS 
WITH 
  -- 1.1. position-Based Multi-File CSV Streaming & Midnight Encodings
  raw_stream AS (
      SELECT 
              c1::smallint as year_nbr
            , c3::smallint as month_nbr
            , c6::date as flight_date
            , c6::varchar as dt_str
            , nullif(trim(c9), '')::varchar(3) as airline_oai_code
            , c8::integer as airline_usdot_id
            , nullif(trim(c10), '')::varchar(10) as tail_nbr
            , lpad(c11::varchar, 4, '0')::char(4) as flight_nbr
            , coalesce(c54::smallint, 1) as flight_count
            , c12::integer as depart_airport_oai_id
            , nullif(trim(c15), '')::char(3) as depart_airport_oai_code
            , c21::integer as arrive_airport_oai_id
            , nullif(trim(c24), '')::char(3) as arrive_airport_oai_code
            , c55::smallint as distance_smi
            , c56::smallint as distance_group_id
            , nullif(trim(c36), '')::varchar(10) as depart_time_block
            , nullif(trim(c47), '')::varchar(10) as arrive_time_block
            
            -- Keep text primitives safe for timestamp mapping logic
            , nullif(trim(c30), '')::char(4) as report_depart_time_lcl
            , nullif(trim(c31), '')::char(4) as actual_depart_time_lcl
            , nullif(trim(c41), '')::char(4) as report_arrive_time_lcl
            , nullif(trim(c42), '')::char(4) as actual_arrive_time_lcl
            , nullif(trim(c38), '')::char(4) as wheels_off_time_lcl
            , nullif(trim(c39), '')::char(4) as wheels_on_time_lcl
            , nullif(trim(c62), '')::char(4) as first_gate_depart_time
            
            -- Register 2400 Midnight Indicator Arrays inline on the reader vectors
            , CASE WHEN nullif(trim(c30), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c30), ''), '0000'), 4, '0') END as r_dep
            , CASE WHEN nullif(trim(c30), '') = '2400' THEN TRUE ELSE FALSE END as r_dep_roll_ind
            , CASE WHEN nullif(trim(c41), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c41), ''), '0000'), 4, '0') END as r_arr
            , CASE WHEN nullif(trim(c41), '') = '2400' THEN TRUE ELSE FALSE END as r_arr_roll_ind
            , CASE WHEN nullif(trim(c31), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c31), ''), '0000'), 4, '0') END as a_dep
            , CASE WHEN nullif(trim(c31), '') = '2400' THEN TRUE ELSE FALSE END as a_dep_roll_ind
            , CASE WHEN nullif(trim(c42), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c42), ''), '0000'), 4, '0') END as a_arr
            , CASE WHEN nullif(trim(c42), '') = '2400' THEN TRUE ELSE FALSE END as a_arr_roll_ind
            , CASE WHEN nullif(trim(c38), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c38), ''), '0000'), 4, '0') END as w_off
            , CASE WHEN nullif(trim(c38), '') = '2400' THEN TRUE ELSE FALSE END as w_off_roll_ind
            , CASE WHEN nullif(trim(c39), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c39), ''), '0000'), 4, '0') END as w_on
            , CASE WHEN nullif(trim(c39), '') = '2400' THEN TRUE ELSE FALSE END as w_on_roll_ind
            , CASE WHEN nullif(trim(c62), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c62), ''), '0000'), 4, '0') END as f_gate
            , CASE WHEN nullif(trim(c62), '') = '2400' THEN TRUE ELSE FALSE END as f_gate_roll_ind

            , c51::integer as report_elapsed_time_min
            , c52::integer as actual_elapsed_time_min
            , c53::integer as airborne_time_min
            , c37::integer as taxi_out_min
            , c40::integer as taxi_in_min
            , nullif(trim(c63), '')::integer as total_ground_time
            , nullif(trim(c64), '')::integer as longest_ground_time
            , coalesce(c48::smallint, 0) as cancelled_ind
            , nullif(trim(c49), '')::varchar(25) as cancellation_code
            , coalesce(c50::smallint, 0) as diverted_ind
            , c57::smallint as airline_delay_min
            , c58::smallint as weather_delay_min
            , c59::smallint as nas_delay_min
            , c60::smallint as security_delay_min
            , c61::smallint as late_aircraft_delay_min
            
            -- Diverted Legs 1..5 Extracted with local 2400 indicators
            , nullif(trim(c70), '')::char(3) as diverted1_airport_oai_code
            , nullif(trim(c77), '')::varchar(10) as diverted1_tail_nbr
            , CASE WHEN nullif(trim(c73), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c73), ''), '0000'), 4, '0') END as d1_w_on
            , CASE WHEN nullif(trim(c73), '') = '2400' THEN TRUE ELSE FALSE END as d1_on_roll_ind
            , CASE WHEN nullif(trim(c76), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c76), ''), '0000'), 4, '0') END as d1_w_off
            , CASE WHEN nullif(trim(c76), '') = '2400' THEN TRUE ELSE FALSE END as d1_off_roll_ind
            , c74::smallint as diverted1_total_ground_time_min
            , c75::smallint as diverted1_longest_ground_time_min

            , nullif(trim(c78), '')::char(3) as diverted2_airport_oai_code
            , nullif(trim(c85), '')::varchar(10) as diverted2_tail_nbr
            , CASE WHEN nullif(trim(c81), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c81), ''), '0000'), 4, '0') END as d2_w_on
            , CASE WHEN nullif(trim(c81), '') = '2400' THEN TRUE ELSE FALSE END as d2_on_roll_ind
            , CASE WHEN nullif(trim(c84), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c84), ''), '0000'), 4, '0') END as d2_w_off
            , CASE WHEN nullif(trim(c84), '') = '2400' THEN TRUE ELSE FALSE END as d2_off_roll_ind
            , c82::smallint as diverted2_total_ground_time_min
            , c83::smallint as diverted2_longest_ground_time_min

            , nullif(trim(c86), '')::char(3) as diverted3_airport_oai_code
            , nullif(trim(c93), '')::varchar(10) as diverted3_tail_nbr
            , CASE WHEN nullif(trim(c89), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c89), ''), '0000'), 4, '0') END as d3_w_on
            , CASE WHEN nullif(trim(c89), '') = '2400' THEN TRUE ELSE FALSE END as d3_on_roll_ind
            , CASE WHEN nullif(trim(c92), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c92), ''), '0000'), 4, '0') END as d3_w_off
            , CASE WHEN nullif(trim(c92), '') = '2400' THEN TRUE ELSE FALSE END as d3_off_roll_ind
            , c90::smallint as diverted3_total_ground_time_min
            , c91::smallint as diverted3_longest_ground_time_min

            , nullif(trim(c94), '')::char(3) as diverted4_airport_oai_code
            , nullif(trim(c101), '')::varchar(10) as diverted4_tail_nbr
            , CASE WHEN nullif(trim(c97), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c97), ''), '0000'), 4, '0') END as d4_w_on
            , CASE WHEN nullif(trim(c97), '') = '2400' THEN TRUE ELSE FALSE END as d4_on_roll_ind
            , CASE WHEN nullif(trim(c100), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c100), ''), '0000'), 4, '0') END as d4_w_off
            , CASE WHEN nullif(trim(c100), '') = '2400' THEN TRUE ELSE FALSE END as d4_off_roll_ind
            , c98::smallint as diverted4_total_ground_time_min
            , c99::smallint as diverted4_longest_ground_time_min

            , nullif(trim(c102), '')::char(3) as diverted5_airport_oai_code
            , nullif(trim(c109), '')::varchar(10) as diverted5_tail_nbr
            , CASE WHEN nullif(trim(c105), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c105), ''), '0000'), 4, '0') END as d5_w_on
            , CASE WHEN nullif(trim(c105), '') = '2400' THEN TRUE ELSE FALSE END as d5_on_roll_ind
            , CASE WHEN nullif(trim(c108), '') = '2400' THEN '0000' ELSE lpad(coalesce(nullif(trim(c108), ''), '0000'), 4, '0') END as d5_w_off
            , CASE WHEN nullif(trim(c108), '') = '2400' THEN TRUE ELSE FALSE END as d5_off_roll_ind
            , c106::smallint as diverted5_total_ground_time_min
            , c107::smallint as diverted5_longest_ground_time_min
    from read_csv(
          --'s3://src-aviation/OTP/CSV/*.csv.gz'
          's3://src-aviation/OTP/CSV/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_4.csv.gz'
        , header=true
        , dateformat='%Y-%m-%d'
        , columns={
              'c1': 'VARCHAR'   -- year_nbr
            , 'c2': 'VARCHAR'   -- quarter_nbr
            , 'c3': 'VARCHAR'   -- month_nbr
            , 'c4': 'VARCHAR'   -- day_of_month
            , 'c5': 'VARCHAR'   -- day_of_week
            , 'c6': 'DATE'      -- flight_date
            , 'c7': 'VARCHAR'   -- airline_unique_oai_code
            , 'c8': 'VARCHAR'   -- airline_usdot_id
            , 'c9': 'VARCHAR'   -- airline_oai_code
            , 'c10': 'VARCHAR'  -- tail_nbr
            , 'c11': 'VARCHAR'  -- flight_nbr
            , 'c12': 'VARCHAR'  -- depart_airport_oai_id
            , 'c13': 'VARCHAR'  -- depart_airport_seq_id
            , 'c14': 'VARCHAR'  -- depart_city_market_id
            , 'c15': 'VARCHAR'  -- depart_airport_oai_code
            , 'c16': 'VARCHAR'  -- depart_city_name
            , 'c17': 'VARCHAR'  -- depart_state_iso_code
            , 'c18': 'VARCHAR'  -- depart_state_fips_code
            , 'c19': 'VARCHAR'  -- depart_state_name
            , 'c20': 'VARCHAR'  -- depart_world_area_oai_id
            , 'c21': 'VARCHAR'  -- arrive_airport_oai_id
            , 'c22': 'VARCHAR'  -- arrive_airport_seq_oai_id
            , 'c23': 'VARCHAR'  -- arrive_city_market_id
            , 'c24': 'VARCHAR'  -- arrive_airport_oai_code
            , 'c25': 'VARCHAR'  -- arrive_city_name
            , 'c26': 'VARCHAR'  -- arrive_state_iso_code
            , 'c27': 'VARCHAR'  -- arrive_state_fips_code
            , 'c28': 'VARCHAR'  -- arrive_state_name
            , 'c29': 'VARCHAR'  -- arrive_world_area_oai_id
            , 'c30': 'VARCHAR'  -- report_depart_time_lcl
            , 'c31': 'VARCHAR'  -- actual_depart_time_lcl
            , 'c32': 'VARCHAR'  -- depart_delay_min
            , 'c33': 'VARCHAR'  -- depart_delay_pos_min
            , 'c34': 'VARCHAR'  -- depart_delay_15min_ind
            , 'c35': 'VARCHAR'  -- depart_delay_group_id
            , 'c36': 'VARCHAR'  -- depart_time_block
            , 'c37': 'VARCHAR'  -- taxi_out_min
            , 'c38': 'VARCHAR'  -- wheels_off_time_lcl
            , 'c39': 'VARCHAR'  -- wheels_on_time_lcl
            , 'c40': 'VARCHAR'  -- taxi_in_min
            , 'c41': 'VARCHAR'  -- report_arrive_time_lcl
            , 'c42': 'VARCHAR'  -- actual_arrive_time_lcl
            , 'c43': 'VARCHAR'  -- arrive_delay_min
            , 'c44': 'VARCHAR'  -- arrive_delay_pos_min
            , 'c45': 'VARCHAR'  -- arrive_delay_15min_ind
            , 'c46': 'VARCHAR'  -- arrive_delay_group_id
            , 'c47': 'VARCHAR'  -- arrive_time_block
            , 'c48': 'VARCHAR'  -- cancelled_ind
            , 'c49': 'VARCHAR'  -- cancellation_code
            , 'c50': 'VARCHAR'  -- diverted_ind
            , 'c51': 'VARCHAR'  -- report_elapsed_time_min
            , 'c52': 'VARCHAR'  -- actual_elapsed_time_min
            , 'c53': 'VARCHAR'  -- airborne_time_min
            , 'c54': 'VARCHAR'  -- flight_count
            , 'c55': 'VARCHAR'  -- distance_smi
            , 'c56': 'VARCHAR'  -- distance_group_id
            , 'c57': 'VARCHAR'  -- airline_delay_min
            , 'c58': 'VARCHAR'  -- weather_delay_min
            , 'c59': 'VARCHAR'  -- nas_delay_min
            , 'c60': 'VARCHAR'  -- security_delay_min
            , 'c61': 'VARCHAR'  -- late_aircraft_delay_min
            , 'c62': 'VARCHAR'  -- first_gate_depart_time
            , 'c63': 'VARCHAR'  -- total_ground_time
            , 'c64': 'VARCHAR'  -- longest_ground_time
            , 'c65': 'VARCHAR'  -- diverted_airport_landing_count
            , 'c66': 'VARCHAR'  -- diverted_reached_dest_ind
            , 'c67': 'VARCHAR'  -- diverted_actual_elapsed_time_min
            , 'c68': 'VARCHAR'  -- diverted_arrive_delay_min
            , 'c69': 'VARCHAR'  -- diverted_distance_smi
            , 'c70': 'VARCHAR'  -- diverted1_airport_oai_code
            , 'c71': 'VARCHAR'  -- diverted1_airport_oai_id
            , 'c72': 'VARCHAR'  -- diverted1_airport_seq_oai_id
            , 'c73': 'VARCHAR'  -- diverted1_wheels_on_time_lcl
            , 'c74': 'VARCHAR'  -- diverted1_total_ground_time_min
            , 'c75': 'VARCHAR'  -- diverted1_longest_ground_time_min
            , 'c76': 'VARCHAR'  -- diverted1_wheels_off_time_lcl
            , 'c77': 'VARCHAR'  -- diverted1_tail_nbr
            , 'c78': 'VARCHAR'  -- diverted2_airport_oai_code
            , 'c79': 'VARCHAR'  -- diverted2_airport_oai_id
            , 'c80': 'VARCHAR'  -- diverted2_airport_seq_oai_id
            , 'c81': 'VARCHAR'  -- diverted2_wheels_on_time_lcl
            , 'c82': 'VARCHAR'  -- diverted2_total_ground_time_min
            , 'c83': 'VARCHAR'  -- diverted2_longest_ground_time_min
            , 'c84': 'VARCHAR'  -- diverted2_wheels_off_time_lcl
            , 'c85': 'VARCHAR'  -- diverted2_tail_nbr
            , 'c86': 'VARCHAR'  -- diverted3_airport_oai_code
            , 'c87': 'VARCHAR'  -- diverted3_airport_oai_id
            , 'c88': 'VARCHAR'  -- diverted3_airport_seq_oai_id
            , 'c89': 'VARCHAR'  -- diverted3_wheels_on_time_lcl
            , 'c90': 'VARCHAR'  -- diverted3_total_ground_time_min
            , 'c91': 'VARCHAR'  -- diverted3_longest_ground_time_min
            , 'c92': 'VARCHAR'  -- diverted3_wheels_off_time_lcl
            , 'c93': 'VARCHAR'  -- diverted3_tail_nbr
            , 'c94': 'VARCHAR'  -- diverted4_airport_oai_code
            , 'c95': 'VARCHAR'  -- diverted4_airport_oai_id
            , 'c96': 'VARCHAR'  -- diverted4_airport_seq_oai_id
            , 'c97': 'VARCHAR'  -- diverted4_wheels_on_time_lcl
            , 'c98': 'VARCHAR'  -- diverted4_total_ground_time_min
            , 'c99': 'VARCHAR'  -- diverted4_longest_ground_time_min
            , 'c100': 'VARCHAR' -- diverted4_wheels_off_time_lcl
            , 'c101': 'VARCHAR' -- diverted4_tail_nbr
            , 'c102': 'VARCHAR' -- diverted5_airport_oai_code
            , 'c103': 'VARCHAR' -- diverted5_airport_oai_id
            , 'c104': 'VARCHAR' -- diverted5_airport_seq_oai_id
            , 'c105': 'VARCHAR' -- diverted5_wheels_on_time_lcl
            , 'c106': 'VARCHAR' -- diverted5_total_ground_time_min
            , 'c107': 'VARCHAR' -- diverted5_longest_ground_time_min
            , 'c108': 'VARCHAR' -- diverted5_wheels_off_time_lcl
            , 'c109': 'VARCHAR' -- diverted5_tail_nbr
            , 'c110': 'VARCHAR' -- filler
          }
          )
      ),
	  
    -- 1.2. multi-Dimensional Range Interval Asymmetric Lookups
    joined_stream AS (
        SELECT 
              ts.*
            , ae.source_from_date as airline_entity_from_date, ae.airline_entity_id, ae.airline_entity_key
            , a.effective_from_date as depart_airport_from_date, a.airport_history_id as depart_airport_history_id, a.airport_history_key as depart_airport_history_key, a.time_zone_name as dep_tz
            , b.effective_from_date as arrive_airport_from_date, b.airport_history_id as arrive_airport_history_id, b.airport_history_key as arrive_airport_history_key, b.time_zone_name as arr_tz
            -- Diverted Core SDC2 Entity Mappings
            , d1.airport_history_id as diverted1_airport_history_id, d1.airport_history_key as diverted1_airport_history_key, d1.time_zone_name as d1_tz, d1.effective_from_date as diverted1_airport_from_date
            , d2.airport_history_id as diverted2_airport_history_id, d2.airport_history_key as diverted2_airport_history_key, d2.time_zone_name as d2_tz, d2.effective_from_date as diverted2_airport_from_date
            , d3.airport_history_id as diverted3_airport_history_id, d3.airport_history_key as diverted3_airport_history_key, d3.time_zone_name as d3_tz, d3.effective_from_date as diverted3_airport_from_date
            , d4.airport_history_id as diverted4_airport_history_id, d4.airport_history_key as diverted4_airport_history_key, d4.time_zone_name as d4_tz, d4.effective_from_date as diverted4_airport_from_date
            , d5.airport_history_id as diverted5_airport_history_id, d5.airport_history_key as diverted5_airport_history_key, d5.time_zone_name as d5_tz, d5.effective_from_date as diverted5_airport_from_date
        FROM raw_stream ts
        LEFT JOIN clean_airlines_lookup ae   ON ts.airline_oai_code = ae.airline_oai_code AND ts.flight_date >= ae.source_from_date AND ts.flight_date < ae.source_thru_date_clean
        LEFT JOIN clean_airports_lookup a   ON ts.depart_airport_oai_code = a.airport_oai_code AND ts.flight_date >= a.effective_from_date AND ts.flight_date < a.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup b   ON ts.arrive_airport_oai_code = b.airport_oai_code AND ts.flight_date >= b.effective_from_date AND ts.flight_date < b.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup d1  ON ts.diverted1_airport_oai_code = d1.airport_oai_code AND ts.flight_date >= d1.effective_from_date AND ts.flight_date < d1.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup d2  ON ts.diverted2_airport_oai_code = d2.airport_oai_code AND ts.flight_date >= d2.effective_from_date AND ts.flight_date < d2.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup d3  ON ts.diverted3_airport_oai_code = d3.airport_oai_code AND ts.flight_date >= d3.effective_from_date AND ts.flight_date < d3.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup d4  ON ts.diverted4_airport_oai_code = d4.airport_oai_code AND ts.flight_date >= d4.effective_from_date AND ts.flight_date < d4.effective_thru_date_clean
        LEFT JOIN clean_airports_lookup d5  ON ts.diverted5_airport_oai_code = d5.airport_oai_code AND ts.flight_date >= d5.effective_from_date AND ts.flight_date < d5.effective_thru_date_clean
    ),
	
    -- 1.3. vectorized String Tokenization & Temporal Additions (+1 Day Loops)
    parsed_timestamps AS (
        SELECT 
              js.*
            , CASE WHEN js.report_depart_time_lcl IS NULL THEN NULL WHEN js.r_dep_roll_ind THEN strptime(js.dt_str || js.r_dep, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.r_dep, '%Y-%m-%d%H%M') END as lcl_r_dep
            , CASE WHEN js.report_arrive_time_lcl IS NULL THEN NULL WHEN js.r_arr_roll_ind THEN strptime(js.dt_str || js.r_arr, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.r_arr, '%Y-%m-%d%H%M') END as lcl_r_arr
            , CASE WHEN js.actual_depart_time_lcl IS NULL THEN NULL WHEN js.a_dep_roll_ind THEN strptime(js.dt_str || js.a_dep, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.a_dep, '%Y-%m-%d%H%M') END as lcl_a_dep
            , CASE WHEN js.actual_arrive_time_lcl IS NULL THEN NULL WHEN js.a_arr_roll_ind THEN strptime(js.dt_str || js.a_arr, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.a_arr, '%Y-%m-%d%H%M') END as lcl_a_arr
            , CASE WHEN js.wheels_off_time_lcl    IS NULL THEN NULL WHEN js.w_off_roll_ind THEN strptime(js.dt_str || js.w_off, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.w_off, '%Y-%m-%d%H%M') END as lcl_w_off
            , CASE WHEN js.wheels_on_time_lcl     IS NULL THEN NULL WHEN js.w_on_roll_ind  THEN strptime(js.dt_str || js.w_on,  '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.w_on,  '%Y-%m-%d%H%M') END as lcl_w_on
            , CASE WHEN js.first_gate_depart_time IS NULL THEN NULL WHEN js.f_gate_roll_ind then strptime(js.dt_str || js.f_gate, '%Y-%m-%d%H%M') + INTERVAL 1 DAY ELSE strptime(js.dt_str || js.f_gate, '%Y-%m-%d%H%M') END as lcl_f_gate
            
            -- Diverted Legs 1..5 Time Vector Offsets
            , CASE WHEN js.diverted1_airport_oai_code IS NOT NULL AND js.d1_w_on  != '0000' THEN strptime(js.dt_str || js.d1_w_on, '%Y-%m-%d%H%M') + CASE WHEN js.d1_on_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d1_on
            , CASE WHEN js.diverted1_airport_oai_code IS NOT NULL AND js.d1_w_off != '0000' THEN strptime(js.dt_str || js.d1_w_off, '%Y-%m-%d%H%M') + CASE WHEN js.d1_off_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d1_off
            
            , CASE WHEN js.diverted2_airport_oai_code IS NOT NULL AND js.d2_w_on  != '0000' THEN strptime(js.dt_str || js.d2_w_on, '%Y-%m-%d%H%M') + CASE WHEN js.d2_on_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d2_on
            , CASE WHEN js.diverted2_airport_oai_code IS NOT NULL AND js.d2_w_off != '0000' THEN strptime(js.dt_str || js.d2_w_off, '%Y-%m-%d%H%M') + CASE WHEN js.d2_off_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d2_off
            
            , CASE WHEN js.diverted3_airport_oai_code IS NOT NULL AND js.d3_w_on  != '0000' THEN strptime(js.dt_str || js.d3_w_on, '%Y-%m-%d%H%M') + CASE WHEN js.d3_on_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d3_on
            , CASE WHEN js.diverted3_airport_oai_code IS NOT NULL AND js.d3_w_off != '0000' THEN strptime(js.dt_str || js.d3_w_off, '%Y-%m-%d%H%M') + CASE WHEN js.d3_off_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d3_off
            
            , CASE WHEN js.diverted4_airport_oai_code IS NOT NULL AND js.d4_w_on  != '0000' THEN strptime(js.dt_str || js.d4_w_on, '%Y-%m-%d%H%M') + CASE WHEN js.d4_on_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d4_on
            , CASE WHEN js.diverted4_airport_oai_code IS NOT NULL AND js.d4_w_off != '0000' THEN strptime(js.dt_str || js.d4_w_off, '%Y-%m-%d%H%M') + CASE WHEN js.d4_off_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d4_off
            
            , CASE WHEN js.diverted5_airport_oai_code IS NOT NULL AND js.d5_w_on  != '0000' THEN strptime(js.dt_str || js.d5_w_on, '%Y-%m-%d%H%M') + CASE WHEN js.d5_on_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d5_on
            , CASE WHEN js.diverted5_airport_oai_code IS NOT NULL AND js.d5_w_off != '0000' THEN strptime(js.dt_str || js.d5_w_off, '%Y-%m-%d%H%M') + CASE WHEN js.d5_off_roll_ind THEN INTERVAL 1 DAY ELSE INTERVAL 0 DAY END ELSE NULL END as lcl_d5_off
        FROM joined_stream js
    )
	
    -- 1.4. final projection with metric serialization
    SELECT 
      md5(ppt.airline_oai_code || '|' || ppt.flight_nbr || '|' || ppt.dt_str || '|' || ppt.depart_airport_oai_code)::char(32) as flight_key
    , ppt.year_nbr
    , ppt.month_nbr
    , ppt.flight_date
    , ppt.airline_oai_code
    , ppt.airline_usdot_id
    , ppt.airline_entity_from_date, ppt.airline_entity_id, ppt.airline_entity_key
    , ppt.flight_nbr, ppt.flight_count, ppt.tail_nbr
    , ppt.depart_airport_oai_id, ppt.depart_airport_oai_code, ppt.depart_airport_from_date, ppt.depart_airport_history_id, ppt.depart_airport_history_key
    , ppt.arrive_airport_oai_id, ppt.arrive_airport_oai_code, ppt.arrive_airport_from_date, ppt.arrive_airport_history_id, ppt.arrive_airport_history_key
    , ppt.distance_smi
    , (ppt.distance_smi * 0.868976)::numeric(10,2) as distance_nmi
    , (ppt.distance_smi * 1.60934)::numeric(10,2) as distance_kmt
    , ppt.distance_group_id, ppt.depart_time_block, ppt.arrive_time_block
    
    -- Localized base timestamps
    , ppt.lcl_r_dep as report_depart_tmstz_lcl, ppt.lcl_r_arr as report_arrive_tmstz_lcl
    , ppt.lcl_a_dep as actual_depart_tmstz_lcl, ppt.lcl_a_arr as actual_arrive_tmstz_lcl
    , ppt.lcl_w_off as wheels_off_tmstz_lcl,   ppt.lcl_w_on as wheels_on_tmstz_lcl
    , ppt.lcl_f_gate as first_gate_depart_tmstz_lcl
    
    -- Timezone Normalization to UTC via native 'at time zone' lookups
    , (ppt.lcl_r_dep at time zone ppt.dep_tz) at time zone 'UTC' as report_depart_tmstz_utc
    , (ppt.lcl_r_arr at time zone ppt.arr_tz) at time zone 'UTC' as report_arrive_tmstz_utc
    , (ppt.lcl_a_dep at time zone ppt.dep_tz) at time zone 'UTC' as actual_depart_tmstz_utc
    , (ppt.lcl_a_arr at time zone ppt.arr_tz) at time zone 'UTC' as actual_arrive_tmstz_utc
    , (ppt.lcl_w_off at time zone ppt.dep_tz) at time zone 'UTC' as wheels_off_tmstz_utc
    , (ppt.lcl_w_on at time zone ppt.arr_tz) at time zone 'UTC' as wheels_on_tmstz_utc
    , (ppt.lcl_f_gate at time zone ppt.dep_tz) at time zone 'UTC' as first_gate_depart_tmstz_utc
    
    , ppt.report_elapsed_time_min, ppt.actual_elapsed_time_min, ppt.airborne_time_min, ppt.taxi_out_min, ppt.taxi_in_min, ppt.total_ground_time, ppt.longest_ground_time
    , ppt.airline_delay_min, ppt.weather_delay_min, ppt.nas_delay_min, ppt.security_delay_min, ppt.late_aircraft_delay_min
    , ppt.cancelled_ind, ppt.cancellation_code, ppt.diverted_ind
    , case when ppt.cancelled_ind = 1 then 'cancelled' when ppt.diverted_ind = 1 then 'diverted' when ppt.airline_delay_min is not null then 'arrived_delayed' else 'arrived_on_time' end::varchar(25) as flight_status

    -- Diverted Leg Outputs 1..5
    , ppt.diverted1_airport_oai_code, ppt.diverted1_airport_history_id, ppt.diverted1_airport_history_key, ppt.diverted1_tail_nbr
    , ppt.lcl_d1_on as diverted1_wheels_on_tmstz_lcl, (ppt.lcl_d1_on at time zone ppt.d1_tz) at time zone 'UTC' as diverted1_wheels_on_tmstz_utc
    , ppt.lcl_d1_off as diverted1_wheels_off_tmstz_lcl, (ppt.lcl_d1_off at time zone ppt.d1_tz) at time zone 'UTC' as diverted1_wheels_off_tmstz_utc
    , ppt.diverted1_total_ground_time_min, ppt.diverted1_longest_ground_time_min, ppt.diverted1_airport_from_date

    , ppt.diverted2_airport_oai_code, ppt.diverted2_airport_history_id, ppt.diverted2_airport_history_key, ppt.diverted2_tail_nbr
    , ppt.lcl_d2_on as diverted2_wheels_on_tmstz_lcl, (ppt.lcl_d2_on at time zone ppt.d2_tz) at time zone 'UTC' as diverted2_wheels_on_tmstz_utc
    , ppt.lcl_d2_off as diverted2_wheels_off_tmstz_lcl, (ppt.lcl_d2_off at time zone ppt.d2_tz) at time zone 'UTC' as diverted2_wheels_off_tmstz_utc
    , ppt.diverted2_total_ground_time_min, ppt.diverted2_longest_ground_time_min, ppt.diverted2_airport_from_date 

    , ppt.diverted3_airport_oai_code, ppt.diverted3_airport_history_id, ppt.diverted3_airport_history_key, ppt.diverted3_tail_nbr
    , ppt.lcl_d3_on as diverted3_wheels_on_tmstz_lcl, (ppt.lcl_d3_on at time zone ppt.d3_tz) at time zone 'UTC' as diverted3_wheels_on_tmstz_utc
    , ppt.lcl_d3_off as diverted3_wheels_off_tmstz_lcl, (ppt.lcl_d3_off at time zone ppt.d3_tz) at time zone 'UTC' as diverted3_wheels_off_tmstz_utc
    , ppt.diverted3_total_ground_time_min, ppt.diverted3_longest_ground_time_min, ppt.diverted3_airport_from_date

    , ppt.diverted4_airport_oai_code, ppt.diverted4_airport_history_id, ppt.diverted4_airport_history_key, ppt.diverted4_tail_nbr
    , ppt.lcl_d4_on as diverted4_wheels_on_tmstz_lcl, (ppt.lcl_d4_on at time zone ppt.d4_tz) at time zone 'UTC' as diverted4_wheels_on_tmstz_utc
    , ppt.lcl_d4_off as diverted4_wheels_off_tmstz_lcl, (ppt.lcl_d4_off at time zone ppt.d4_tz) at time zone 'UTC' as diverted4_wheels_off_tmstz_utc
    , ppt.diverted4_total_ground_time_min, ppt.diverted4_longest_ground_time_min, ppt.diverted4_airport_from_date

    , ppt.diverted5_airport_oai_code, ppt.diverted5_airport_history_id, ppt.diverted5_airport_history_key, ppt.diverted5_tail_nbr
    , ppt.lcl_d5_on as diverted5_wheels_on_tmstz_lcl, (ppt.lcl_d5_on at time zone ppt.d5_tz) at time zone 'UTC' as diverted5_wheels_on_tmstz_utc
    , ppt.lcl_d5_off as diverted5_wheels_off_tmstz_lcl, (ppt.lcl_d5_off at time zone ppt.d5_tz) at time zone 'UTC' as diverted5_wheels_off_tmstz_utc
    , ppt.diverted5_total_ground_time_min, ppt.diverted5_longest_ground_time_min, ppt.diverted5_airport_from_date
FROM parsed_timestamps ppt

-- 2. slice final target tables directly from the integrated hub
-- 2.1. airline_flights_completed
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
from air_oai_facts.airline_flights_completed
where cancelled_ind = 0 and diverted_ind = 0;


-- 2.2. airline_flights_cancelled
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
from air_oai_facts.airline_flights_completed
where cancelled_ind = 1;


-- 2.3. airline_flights_diverted
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
from air_oai_facts.airline_flights_completed
where diverted_ind = 1;


-- 2.4. airline_flights_diverted_legs
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
from air_oai_facts.airline_flights_completed
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
from air_oai_facts.airline_flights_completed
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
from air_oai_facts.airline_flights_completed
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
from air_oai_facts.airline_flights_completed
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
from air_oai_facts.airline_flights_completed
where diverted_ind = 1 and diverted5_airport_history_id is not null;


-- 2.5. airline_flights_scheduled
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


-- 3. add table constraints
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


-- 4. create presentation layer views
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
