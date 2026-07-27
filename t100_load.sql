-- T100 (Market and Segment) (US DoT data) 
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Market (All Carriers)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Segment (All Carriers)	
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EEE&QO_anzr=Nv4%FDPn44vr4%FDf6n6v56vp5%FD%FLS14z%FDHE%FDg4nssvp%FM-%FDNyy%FDPn44vr45&QO_fu146_anzr=Nv4%FDPn44vr45

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month)
-- 1. create and load air_oai_facts.airline_traffic_market (use CTEs to pre-process the data; streaming ~500MB of compressed csv files)
    -- 1.1. materialize SCD2 CTEs
    -- 1.2. position-Based Multi-File CSV Streaming & Midnight Encodings
    -- 1.3. multi-dimensional Range Interval Asymmetric Lookups
    -- 1.4. final projection
-- 2. create and load air_oai_facts.airline_traffic_segment (use CTEs to pre-process the data; streaming ~300MB of compressed csv files)
    -- 2.1. materialize SCD2 CTEs
    -- 2.2. position-Based Multi-File CSV Streaming & Midnight Encodings
    -- 2.3. clean-up stage
    -- 2.4. multi-dimensional Range Interval Asymmetric Lookups
    -- 2.5. final projection
-- 3. create and load air_oai_dims.aircraft_configurations based on air_oai_facts.airline_traffic_segment
-- 4. create and load air_oai_dims.airline_service_classes based on air_oai_facts.airline_traffic_market
-- 5. add table constraints
-- 6. create presentation layer views
----------------------------------------------------

-- 1. create and load air_oai_facts.airline_traffic_market
drop table if exists air_oai_facts.airline_traffic_market;
create table air_oai_facts.airline_traffic_market as
with 
  -- 1.1. materialize SCD2 CTEs
  clean_airlines_lookup as (
      select *, coalesce(source_thru_date, current_date) as source_thru_date_clean
      from air_oai_dims.airline_entities
  ),
  clean_airports_lookup as (
      select *, coalesce(effective_thru_date, current_date) as effective_thru_date_clean
      from air_oai_dims.airport_history
  ),
  -- 1.2. position-Based Multi-File CSV Streaming & Midnight Encodings
  raw_market as (
    select 
          c1::float4 as passengers_qty
        , c2::float4 as freight_lbr
        , c3::float4 as mail_lbr
        , c4::float4 as distance_smi
        , c6::integer as airline_usdot_id
        , nullif(trim(c8), '')::varchar(15) as entity_unique_oai_code
        , nullif(trim(c10), '')::varchar(5) as airline_oai_code
        , nullif(trim(c11), '')::varchar(125) as airline_name
        , c14::integer as depart_airport_oai_id
        , nullif(trim(c17), '')::varchar(5) as depart_airport_oai_code
        , c25::integer as arrive_airport_oai_id
        , nullif(trim(c28), '')::varchar(5) as arrive_airport_oai_code
        , c36::integer as year_nbr
        , c37::integer as quarter_nbr
        , c38::integer as month_nbr
        , nullif(trim(c40), '')::varchar(5) as service_class_code
        , nullif(trim(c41), '')::varchar(5) as data_source_code
        , make_date(c36::integer, c38::integer, 1) as anchor_date
        , (c36::integer * 100 + c38::integer)::integer as year_month_nbr
    from read_csv(
          's3://src-aviation/T100/market/CSV/*.csv.gz'
          --'s3://src-aviation/T100/market/CSV/T100_MARKET_ALL_CARRIER_ALL_2025.csv.gz' 
        , header=true
        , dateformat='%m/%d/%Y %I:%M:%S %p'
        , columns={
              'c1': 'VARCHAR'  -- passengers_qty
            , 'c2': 'VARCHAR'  -- freight_lbr
            , 'c3': 'VARCHAR'  -- mail_lbr
            , 'c4': 'VARCHAR'  -- distance_smi
            , 'c5': 'VARCHAR'  -- airline_unique_oai_code
            , 'c6': 'VARCHAR'  -- airline_usdot_id
            , 'c7': 'VARCHAR'  -- airline_unique_name
            , 'c8': 'VARCHAR'  -- entity_unique_oai_code
            , 'c9': 'VARCHAR'  -- operating_region_code
            , 'c10': 'VARCHAR' -- airline_oai_code
            , 'c11': 'VARCHAR' -- airline_name
            , 'c12': 'VARCHAR' -- airline_old_group_nbr
            , 'c13': 'VARCHAR' -- airline_new_group_nbr
            , 'c14': 'VARCHAR' -- depart_airport_oai_id
            , 'c15': 'VARCHAR' -- depart_airport_oai_seq_id
            , 'c16': 'VARCHAR' -- depart_city_market_oai_id
            , 'c17': 'VARCHAR' -- depart_airport_oai_code
            , 'c18': 'VARCHAR' -- depart_city_name
            , 'c19': 'VARCHAR' -- depart_subdivision_iso_code
            , 'c20': 'VARCHAR' -- depart_subdivision_fips_code
            , 'c21': 'VARCHAR' -- depart_subdivision_name
            , 'c22': 'VARCHAR' -- depart_country_iso_code
            , 'c23': 'VARCHAR' -- depart_country_name
            , 'c24': 'VARCHAR' -- depart_world_area_oai_id
            , 'c25': 'VARCHAR' -- arrive_airport_oai_id
            , 'c26': 'VARCHAR' -- arrive_airport_oai_seq_id
            , 'c27': 'VARCHAR' -- arrive_city_market_oai_id
            , 'c28': 'VARCHAR' -- arrive_airport_oai_code
            , 'c29': 'VARCHAR' -- arrive_city_name
            , 'c30': 'VARCHAR' -- arrive_subdivision_iso_code
            , 'c31': 'VARCHAR' -- arrive_subdivision_fips_code
            , 'c32': 'VARCHAR' -- arrive_subdivision_name
            , 'c33': 'VARCHAR' -- arrive_country_iso_code
            , 'c34': 'VARCHAR' -- arrive_country_name
            , 'c35': 'VARCHAR' -- arrive_world_area_oai_id
            , 'c36': 'VARCHAR' -- year_nbr
            , 'c37': 'VARCHAR' -- quarter_nbr
            , 'c38': 'VARCHAR' -- month_nbr
            , 'c39': 'VARCHAR' -- distance_group_id
            , 'c40': 'VARCHAR' -- service_class_code
            , 'c41': 'VARCHAR' -- data_source_code
          }
    )
  ),
  -- 1.3. multi-Dimensional Range Interval Asymmetric Lookups
  integrated as (
    select 
        f.year_month_nbr
        , f.service_class_code::char(1) as service_class_code
        , f.airline_usdot_id::integer as airline_usdot_id
        , f.airline_oai_code::varchar(3) as airline_oai_code
        , f.entity_unique_oai_code::varchar(15) as entity_oai_code
        , ae.source_from_date as airline_effective_date
        , ae.airline_entity_id
        , ae.airline_entity_key
        , f.depart_airport_oai_code::char(3) as depart_airport_oai_code
        , h1.effective_from_date as depart_airport_effective_date
        , h1.airport_history_id as depart_airport_history_id
        , h1.airport_history_key as depart_airport_history_key
        , f.arrive_airport_oai_code::char(3) as arrive_airport_oai_code
        , h2.effective_from_date as arrive_airport_effective_date
        , h2.airport_history_id as arrive_airport_history_id
        , h2.airport_history_key as arrive_airport_history_key
        , f.data_source_code::varchar(5) as data_source_code
        , f.passengers_qty::float4 as passengers_qty
        , f.freight_lbr::float4 as freight_lbr
        , f.mail_lbr::float4 as mail_lbr
    from raw_market f
    left join clean_airlines_lookup ae
      on f.airline_usdot_id = ae.airline_usdot_id
     and f.airline_oai_code = ae.airline_oai_code
     and f.entity_unique_oai_code = ae.entity_unique_oai_code
     and f.anchor_date >= ae.source_from_date
     and f.anchor_date < ae.source_thru_date_clean
    left join clean_airports_lookup h1
      on f.depart_airport_oai_id = h1.airport_oai_id
     and f.anchor_date >= h1.effective_from_date
     and f.anchor_date < h1.effective_thru_date_clean
    left join clean_airports_lookup h2
      on f.arrive_airport_oai_id = h2.airport_oai_id
     and f.anchor_date >= h2.effective_from_date
     and f.anchor_date < h2.effective_thru_date_clean
)
-- 1.4. final projection
select 
    md5(year_month_nbr::varchar
        ||'|'||service_class_code
        ||'|'||airline_entity_key
        ||'|'||depart_airport_history_key
        ||'|'||arrive_airport_history_key
    )::char(32) as airline_traffic_market_key
    , year_month_nbr::integer as year_month_nbr
    , max(airline_oai_code)::varchar(3) as airline_oai_code
    , max(airline_effective_date)::date as airline_effective_date
    , max(airline_entity_id)::integer as airline_entity_id
    , airline_entity_key::char(32) as airline_entity_key
    , max(depart_airport_oai_code)::char(3) as depart_airport_oai_code
    , max(depart_airport_effective_date)::date as depart_airport_effective_date
    , max(depart_airport_history_id)::integer as depart_airport_history_id
    , depart_airport_history_key::char(32) as depart_airport_history_key
    , max(arrive_airport_oai_code)::char(3) as arrive_airport_oai_code
    , max(arrive_airport_effective_date)::date as arrive_airport_effective_date
    , max(arrive_airport_history_id)::integer as arrive_airport_history_id
    , arrive_airport_history_key::char(32) as arrive_airport_history_key
    , service_class_code::char(1) as service_class_code
    , max(data_source_code)::varchar(5) as data_source_code
    , sum(passengers_qty)::integer as passengers_qty
    , (sum(freight_lbr) * 0.45359237)::numeric(10,1) as freight_kgm
    , (sum(mail_lbr) * 0.45359237)::numeric(10,1) as mail_kgm
    , count(*)::smallint as t100_records_qty
    , null::varchar(32) as metadata_key
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tmst
from integrated
where year_month_nbr is not null 
  and service_class_code is not null 
  and airline_entity_key is not null 
  and depart_airport_history_key is not null 
  and arrive_airport_history_key is not null
group by year_month_nbr, service_class_code, airline_entity_key, depart_airport_history_key, arrive_airport_history_key;


-- 2. create and load air_oai_facts.airline_traffic_segment
drop table if exists air_oai_facts.airline_traffic_segment;
create table air_oai_facts.airline_traffic_segment as
with 
  -- 2.1. materialize SCD2 CTEs
  clean_airlines_lookup as (
    select *, coalesce(source_thru_date, current_date) as source_thru_date_clean
    from air_oai_dims.airline_entities
),
clean_airports_lookup as (
    select *, coalesce(effective_thru_date, current_date) as effective_thru_date_clean
    from air_oai_dims.airport_history
),
-- 2.2. position-Based Multi-File CSV Streaming & Midnight Encodings
raw_segment as (
    select 
          c1::float4 as scheduled_departures_qty
        , c2::float4 as performed_departures_qty
        , c3::float4 as payload_lbr
        , c4::float4 as available_seat_qty
        , c5::float4 as passengers_qty
        , c6::float4 as freight_lbr
        , c7::float4 as mail_lbr
        , c8::float4 as distance_smi
        , c9::float4 as ramp_to_ramp_min
        , c10::float4 as air_time_min
        , c12::integer as airline_usdot_id
        , nullif(trim(c14), '')::varchar(15) as entity_unique_oai_code
        , nullif(trim(c16), '')::varchar(5) as airline_oai_code
        , c20::integer as depart_airport_oai_id
        , nullif(trim(c23), '')::varchar(3) as depart_airport_oai_code
        , nullif(trim(c28), '')::varchar(10) as depart_country_iso_code
        , c31::integer as arrive_airport_oai_id
        , nullif(trim(c34), '')::varchar(5) as arrive_airport_oai_code
        , nullif(trim(c39), '')::varchar(10) as arrive_country_iso_code
        , c43::integer as aircraft_type_oai_nbr
        , c44::integer as aircraft_configuration_id
        , c45::integer as year_nbr
        , c46::integer as quarter_nbr
        , c47::integer as month_nbr
        , nullif(trim(c49), '')::varchar(5) as service_class_code
        , nullif(trim(c50), '')::varchar(5) as data_source_code
        , make_date(c45::integer, c47::integer, 1) as anchor_date
        , (c45::integer * 100 + c47::integer)::integer as year_month_nbr
    from read_csv(
          's3://src-aviation/T100/segment/CSV/*.csv.gz'
          --'s3://src-aviation/T100/segment/CSV/T100_SEGMENT_ALL_CARRIER_ALL_2024.csv.gz'
        , header=true
        , dateformat='%m/%d/%Y %I:%M:%S %p'
        , columns={
              'c1': 'VARCHAR'  -- scheduled_departures_qty
            , 'c2': 'VARCHAR'  -- performed_departures_qty
            , 'c3': 'VARCHAR'  -- payload_lbr
            , 'c4': 'VARCHAR'  -- available_seat_qty
            , 'c5': 'VARCHAR'  -- passengers_qty
            , 'c6': 'VARCHAR'  -- freight_lbr
            , 'c7': 'VARCHAR'  -- mail_lbr
            , 'c8': 'VARCHAR'  -- distance_smi
            , 'c9': 'VARCHAR'  -- ramp_to_ramp_min
            , 'c10': 'VARCHAR' -- air_time_min
            , 'c11': 'VARCHAR' -- airline_unique_oai_code
            , 'c12': 'VARCHAR' -- airline_usdot_id
            , 'c13': 'VARCHAR' -- airline_unique_name
            , 'c14': 'VARCHAR' -- entity_unique_oai_code
            , 'c15': 'VARCHAR' -- operating_region_code
            , 'c16': 'VARCHAR' -- airline_oai_code
            , 'c17': 'VARCHAR' -- airline_name
            , 'c18': 'VARCHAR' -- airline_old_group_nbr
            , 'c19': 'VARCHAR' -- airline_new_group_nbr
            , 'c20': 'VARCHAR' -- depart_airport_oai_id
            , 'c21': 'VARCHAR' -- depart_airport_oai_seq_id
            , 'c22': 'VARCHAR' -- depart_market_city_oai_id
            , 'c23': 'VARCHAR' -- depart_airport_oai_code
            , 'c24': 'VARCHAR' -- depart_city_name
            , 'c25': 'VARCHAR' -- depart_state_cd
            , 'c26': 'VARCHAR' -- depart_state_fips_cd
            , 'c27': 'VARCHAR' -- depart_state_nm
            , 'c28': 'VARCHAR' -- depart_country_iso_code
            , 'c29': 'VARCHAR' -- depart_country_name
            , 'c30': 'VARCHAR' -- depart_world_area_oai_id
            , 'c31': 'VARCHAR' -- arrive_airport_oai_id
            , 'c32': 'VARCHAR' -- arrive_airport_oai_seq_id
            , 'c33': 'VARCHAR' -- arrive_market_city_oai_id
            , 'c34': 'VARCHAR' -- arrive_airport_oai_code
            , 'c35': 'VARCHAR' -- arrive_city_name
            , 'c36': 'VARCHAR' -- arrive_subdivision_iso_code
            , 'c37': 'VARCHAR' -- arrive_subdivision_fips_code
            , 'c38': 'VARCHAR' -- arrive_subdivision_name
            , 'c39': 'VARCHAR' -- arrive_country_iso_code
            , 'c40': 'VARCHAR' -- arrive_country_name
            , 'c41': 'VARCHAR' -- arrive_world_area_oai_id
            , 'c42': 'VARCHAR' -- aircraft_group_oai_nbr
            , 'c43': 'VARCHAR' -- aircraft_type_oai_nbr
            , 'c44': 'VARCHAR' -- aircraft_configuration_id
            , 'c45': 'VARCHAR' -- year_nbr
            , 'c46': 'VARCHAR' -- quarter_nbr
            , 'c47': 'VARCHAR' -- month_nbr
            , 'c48': 'VARCHAR' -- distance_group_id
            , 'c49': 'VARCHAR' -- service_class_code
            , 'c50': 'VARCHAR' -- data_source_code
          }
    )
  ),
  -- 2.3. clean-up stage
  cleaned as (
    select 
        f.anchor_date
        , f.year_month_nbr
        , f.scheduled_departures_qty
        , f.performed_departures_qty
        , f.available_seat_qty
        , f.passengers_qty
        , f.freight_lbr
        , f.mail_lbr
        , f.ramp_to_ramp_min
        , f.air_time_min
        , case when airline_oai_code = '5G' and airline_usdot_id is null then 21181
          when airline_oai_code = '0OQ' and airline_usdot_id is null then 21287
          when airline_oai_code = 'AQ' and airline_usdot_id is null then 19678
          when airline_oai_code = 'KH' and airline_usdot_id = 19678 then 21634
          when airline_oai_code = 'K8' and airline_usdot_id is null then 20310
          when airline_oai_code = 'XP' and airline_usdot_id is null then 20207
          when airline_oai_code = '2HQ' and airline_usdot_id is null then 21712
          else airline_usdot_id end::integer as airline_usdot_id
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
        , case when airline_oai_code = '39Q' and airline_usdot_id = 21894 then 'AN'
          when airline_oai_code = '3GQ' and airline_usdot_id = 21869 then '36Q'
          when airline_oai_code = 'A0' and airline_usdot_id = 20234 and entity_unique_oai_code = '9486F' then '8R'
          else airline_oai_code end::varchar(5) as airline_oai_code
        , f.depart_airport_oai_id
        , f.depart_airport_oai_code
        , f.arrive_airport_oai_id
        , f.arrive_airport_oai_code
        , f.aircraft_type_oai_nbr::integer as aircraft_type_oai_nbr
        , f.aircraft_configuration_id
        , f.service_class_code
        , f.data_source_code
    from raw_segment f
),
-- 2.4. multi-Dimensional Range Interval Asymmetric Lookups
integrated as (
    select 
        f.year_month_nbr
        , f.service_class_code::char(1) as service_class_code
        , f.airline_usdot_id
        , f.airline_oai_code::varchar(3) as airline_oai_code
        , f.entity_unique_oai_code as entity_oai_code
        , ae.source_from_date as airline_effective_date
        , ae.airline_entity_id
        , ae.airline_entity_key
        , f.depart_airport_oai_code::char(3) as depart_airport_oai_code
        , h1.effective_from_date as depart_airport_effective_date
        , h1.airport_history_id as depart_airport_history_id
        , h1.airport_history_key as depart_airport_history_key
        , f.arrive_airport_oai_code::char(3) as arrive_airport_oai_code
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
        , f.data_source_code::varchar(5) as data_source_code
        , f.passengers_qty::float4 as passengers_qty
        , f.freight_lbr::float4 as freight_lbr
        , f.mail_lbr::float4 as mail_lbr
        , f.available_seat_qty::float4 as available_seat_qty
        , f.scheduled_departures_qty::float4 as scheduled_departures_qty
        , f.performed_departures_qty::float4 as performed_departures_qty
        , f.ramp_to_ramp_min::float4 as ramp_to_ramp_min
        , f.air_time_min::float4 as air_time_min
    from cleaned f
    left join clean_airlines_lookup ae
      on f.airline_usdot_id = ae.airline_usdot_id
     and f.airline_oai_code = ae.airline_oai_code
     and f.entity_unique_oai_code = ae.entity_unique_oai_code
     and f.anchor_date >= ae.source_from_date
     and f.anchor_date < ae.source_thru_date_clean
    left join clean_airports_lookup h1
      on f.depart_airport_oai_id = h1.airport_oai_id
     and f.anchor_date >= h1.effective_from_date
     and f.anchor_date < h1.effective_thru_date_clean
    left join clean_airports_lookup h2
      on f.arrive_airport_oai_id = h2.airport_oai_id
     and f.anchor_date >= h2.effective_from_date
     and f.anchor_date < h2.effective_thru_date_clean
)
-- 2.5. final projection
select 
    md5(year_month_nbr::varchar
        ||'|'||service_class_code
        ||'|'||airline_entity_key
        ||'|'||depart_airport_history_key
        ||'|'||arrive_airport_history_key
        ||'|'||lpad(aircraft_type_oai_nbr::varchar,3,'0')
        ||'|'||aircraft_configuration_ref
    )::char(32) as airline_traffic_segment_key
    , year_month_nbr::integer as year_month_nbr
    , service_class_code::char(1) as service_class_code
    , max(airline_oai_code)::varchar(3) as airline_oai_code
    , max(airline_effective_date)::date as airline_effective_date
    , max(airline_entity_id)::integer as airline_entity_id
    , airline_entity_key::char(32) as airline_entity_key
    , max(depart_airport_oai_code)::char(3) as depart_airport_oai_code
    , max(depart_airport_effective_date)::date as depart_airport_effective_date
    , max(depart_airport_history_id)::integer as depart_airport_history_id
    , depart_airport_history_key::char(32) as depart_airport_history_key
    , max(arrive_airport_oai_code)::char(3) as arrive_airport_oai_code
    , max(arrive_airport_effective_date)::date as arrive_airport_effective_date
    , max(arrive_airport_history_id)::integer as arrive_airport_history_id
    , arrive_airport_history_key::char(32) as arrive_airport_history_key
    , aircraft_type_oai_nbr::integer as aircraft_type_oai_nbr
    , aircraft_configuration_ref::char(3) as aircraft_configuration_ref
    , max(data_source_code)::varchar(5) as data_source_code
    , sum(scheduled_departures_qty)::integer as scheduled_departures_qty
    , sum(performed_departures_qty)::integer as performed_departures_qty
    , sum(available_seat_qty)::integer as available_seat_qty
    , sum(passengers_qty)::integer as passengers_qty
    , (sum(freight_lbr) * 0.45359237)::numeric(10,1) as freight_kgm
    , (sum(mail_lbr) * 0.45359237)::numeric(10,1) as mail_kgm
    , sum(ramp_to_ramp_min)::integer as ramp_to_ramp_min
    , sum(air_time_min)::integer as air_time_min
    , count(*)::smallint as t100_records_qty
    , null::varchar(32) as metadata_key
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tmst
from integrated
where year_month_nbr is not null 
  and service_class_code is not null 
  and airline_entity_key is not null 
  and depart_airport_history_key is not null 
  and arrive_airport_history_key is not null
group by year_month_nbr, service_class_code, airline_entity_key, depart_airport_history_key, arrive_airport_history_key, aircraft_type_oai_nbr, aircraft_configuration_ref;

-- 3. create and load air_oai_dims.aircraft_configurations based on air_oai_facts.airline_traffic_segment
drop table if exists air_oai_dims.aircraft_configurations;
create table air_oai_dims.aircraft_configurations as
select distinct aircraft_configuration_ref
     , case aircraft_configuration_ref
         when 'N/A' then 'Not Applicable'
         when 'PAX' then 'Passenger'
         when 'FRT' then 'Freight/Cargo'
         when 'CMB' then 'Combination (Passenger & Cargo)'
         when 'SEA' then 'Seaplane'
         when 'EXP' then 'Expenses'
         else 'Unknown' end::varchar(55) as aircraft_configuration_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp as created_tmst
from air_oai_facts.airline_traffic_segment;


-- 4. create and load air_oai_dims.airline_service_classes based on air_oai_facts.airline_traffic_market
drop table if exists air_oai_dims.airline_service_classes;
create table air_oai_dims.airline_service_classes as
select distinct service_class_code
     , case service_class_code
         when 'F' then 'Scheduled Passenger / Cargo'
         when 'G' then 'Scheduled All-Cargo'
         when 'L' then 'Nonscheduled Civil Passenger / Cargo'
         when 'P' then 'Nonscheduled Civil All-Cargo'
         when 'N' then 'Nonscheduled Military Passenger / Cargo'
         when 'R' then 'Nonscheduled Military All-Cargo'
         when 'Q' then 'Nonscheduled Service (Passenger or Cargo)'
         when 'Z' then 'All Services'
         else 'Unknown' end::varchar(55) as service_class_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp as created_tmst
from air_oai_facts.airline_traffic_market;


-- 5. add table constraints
alter table air_oai_facts.airline_traffic_market alter airline_traffic_market_key set not null;
alter table air_oai_facts.airline_traffic_market alter year_month_nbr set not null;
alter table air_oai_facts.airline_traffic_market alter airline_oai_code set not null;
alter table air_oai_facts.airline_traffic_market alter airline_effective_date set not null;
alter table air_oai_facts.airline_traffic_market alter airline_entity_id set not null;
alter table air_oai_facts.airline_traffic_market alter airline_entity_key set not null;
alter table air_oai_facts.airline_traffic_market alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_traffic_market alter depart_airport_effective_date set not null;
alter table air_oai_facts.airline_traffic_market alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_traffic_market alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_traffic_market alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_traffic_market alter arrive_airport_effective_date set not null;
alter table air_oai_facts.airline_traffic_market alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_traffic_market alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_traffic_market alter service_class_code set not null;
alter table air_oai_facts.airline_traffic_market alter data_source_code set not null;
alter table air_oai_facts.airline_traffic_market alter passengers_qty set not null;
alter table air_oai_facts.airline_traffic_market alter mail_kgm set not null;
alter table air_oai_facts.airline_traffic_market alter t100_records_qty set not null;
alter table air_oai_facts.airline_traffic_market alter created_by set not null;
alter table air_oai_facts.airline_traffic_market alter created_tmst set not null;
alter table air_oai_facts.airline_traffic_market add constraint airline_traffic_market_pk primary key (airline_traffic_market_key);

-- airline_traffic_segment
alter table air_oai_facts.airline_traffic_segment alter airline_traffic_segment_key set not null;
alter table air_oai_facts.airline_traffic_segment alter year_month_nbr set not null;
alter table air_oai_facts.airline_traffic_segment alter service_class_code set not null;
alter table air_oai_facts.airline_traffic_segment alter airline_oai_code set not null;
alter table air_oai_facts.airline_traffic_segment alter airline_effective_date set not null;
alter table air_oai_facts.airline_traffic_segment alter airline_entity_id set not null;
alter table air_oai_facts.airline_traffic_segment alter airline_entity_key set not null;
alter table air_oai_facts.airline_traffic_segment alter depart_airport_oai_code set not null;
alter table air_oai_facts.airline_traffic_segment alter depart_airport_effective_date set not null;
alter table air_oai_facts.airline_traffic_segment alter depart_airport_history_id set not null;
alter table air_oai_facts.airline_traffic_segment alter depart_airport_history_key set not null;
alter table air_oai_facts.airline_traffic_segment alter arrive_airport_oai_code set not null;
alter table air_oai_facts.airline_traffic_segment alter arrive_airport_effective_date set not null;
alter table air_oai_facts.airline_traffic_segment alter arrive_airport_history_id set not null;
alter table air_oai_facts.airline_traffic_segment alter arrive_airport_history_key set not null;
alter table air_oai_facts.airline_traffic_segment alter aircraft_type_oai_nbr set not null;
alter table air_oai_facts.airline_traffic_segment alter aircraft_configuration_ref set not null;
alter table air_oai_facts.airline_traffic_segment alter data_source_code set not null;
alter table air_oai_facts.airline_traffic_segment alter scheduled_departures_qty set not null;
alter table air_oai_facts.airline_traffic_segment alter performed_departures_qty set not null;
alter table air_oai_facts.airline_traffic_segment alter available_seat_qty set not null;
alter table air_oai_facts.airline_traffic_segment alter passengers_qty set not null;
alter table air_oai_facts.airline_traffic_segment alter freight_kgm set not null;
alter table air_oai_facts.airline_traffic_segment alter mail_kgm set not null;
alter table air_oai_facts.airline_traffic_segment alter ramp_to_ramp_min set not null;
alter table air_oai_facts.airline_traffic_segment alter air_time_min set not null;
alter table air_oai_facts.airline_traffic_segment alter t100_records_qty set not null;
alter table air_oai_facts.airline_traffic_segment alter created_by set not null;
alter table air_oai_facts.airline_traffic_segment alter created_tmst set not null;
alter table air_oai_facts.airline_traffic_segment add constraint airline_traffic_segment_pk primary key (airline_traffic_segment_key);


-- 6. create presentation layer views
-- drop view if exists airlines_ddb.aircraft_configurations_v;
create or replace view airlines_ddb.aircraft_configurations_v as
SELECT aircraft_configuration_ref
	 , aircraft_configuration_descr
FROM air_oai_dims.aircraft_configurations;

-- drop view if exists airlines_ddb.airline_service_classes_v;
create or replace view airlines_ddb.airline_service_classes_v as
SELECT service_class_code
	 , service_class_descr
FROM air_oai_dims.airline_service_classes;

-- drop view if exists airlines_ddb.airline_traffic_market_v;
create or replace view airlines_ddb.airline_traffic_market_v as
SELECT airline_traffic_market_key, year_month_nbr, service_class_code
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, data_source_code, passengers_qty, freight_kgm, mail_kgm, t100_records_qty
FROM air_oai_facts.airline_traffic_market;

-- drop view if exists airlines_ddb.airline_traffic_segment_v;
create or replace view airlines_ddb.airline_traffic_segment_v as
SELECT airline_traffic_segment_key, year_month_nbr, service_class_code
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, aircraft_type_oai_nbr, aircraft_configuration_ref, data_source_code
	, scheduled_departures_qty, performed_departures_qty, available_seat_qty, passengers_qty
	, freight_kgm, mail_kgm, ramp_to_ramp_min, air_time_min, t100_records_qty
FROM air_oai_facts.airline_traffic_segment;
