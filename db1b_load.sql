-- DB1B (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BTicket
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BCoupon
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BMarket
-- https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFI&Yv0x=D

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. process DB1B Ticket data
    -- 1.1. materialize SCD2 CTEs
    -- 1.2. position-Based Multi-File CSV Streaming
    -- 1.3. multi-dimensional range interval lookups and projection
-- 2. process DB1B Coupon data
    -- 2.1. materialize SCD2 CTEs
    -- 2.2. position-Based Multi-File CSV Streaming
    -- 2.3. multi-dimensional range interval lookups and projection
-- 3. process DB1B Market data
    -- 3.1. materialize SCD2 CTEs
    -- 3.2. position-Based Multi-File CSV Streaming
    -- 3.3. multi-dimensional range interval lookups and projection
-- 4. add table constraints
-- 5. create presentation layer views
----------------------------------------------------

-- 1. process DB1B Ticket data  
drop table if exists air_oai_facts.airfare_survey_itinerary;
create table air_oai_facts.airfare_survey_itinerary as
with 
  -- 1.1. materialize SCD2 CTEs
  clean_airlines_lookup as (
      select *, coalesce(source_thru_date, current_date) as source_thru_date_clean
      from air_oai_dims.airline_entities
      where operating_region_code = 'Domestic'
  ),
  -- 1.2. position-Based Multi-File CSV Streaming
  raw_ticket as (
      select 
            c1::bigint as itinerary_oai_id
          , c3::integer as year_nbr
          , c4::integer as quarter_nbr
          , make_date(c3::integer, (c4::integer - 1) * 3 + 1, 1) as year_quarter_start_date
          , (c3::integer * 10 + c4::integer)::integer as year_quarter_nbr
          , nullif(trim(c5), '')::char(3) as depart_airport_oai_code
          , c7::integer as depart_airport_oai_seq_id
          , nullif(trim(c18), '')::varchar(3) as reporting_airline_oai_code
          , c14::smallint as round_trip_fare_ind
          , c15::smallint as online_purchase_ind
          , c21::smallint as bulk_fare_ind
          , c16::smallint as fare_credibility_ind
          , c23::smallint as distance_group_oai_id
          , c25::smallint as geographic_type_oai_id
          , c2::smallint as coupon_qty
          , c19::smallint as passenger_qty
          , c22::integer as distance_smi
          , c24::integer as flown_distance_smi
          , c20::integer as fare_per_person_usd
          , c17::numeric(10,5) as fare_per_mile_usd
      from read_csv(
            --'s3://src-aviation/DB1B/ticket/CSV/*.csv.gz'
            's3://src-aviation/DB1B/ticket/CSV/Origin_and_Destination_Survey_DB1BTicket_2025_1.csv.gz'
          , header=true
          , dateformat='%m/%d/%Y %I:%M:%S %p'
          , columns={
                'c1': 'VARCHAR'  -- itinerary_oai_id
              , 'c2': 'VARCHAR'  -- coupon_qty
              , 'c3': 'VARCHAR'  -- year_nbr
              , 'c4': 'VARCHAR'  -- quarter_nbr
              , 'c5': 'VARCHAR'  -- depart_airport_oai_code
              , 'c6': 'VARCHAR'  -- depart_airport_oai_id
              , 'c7': 'VARCHAR'  -- depart_airport_oai_seq_id
              , 'c8': 'VARCHAR'  -- depart_market_city_oai_id
              , 'c9': 'VARCHAR'  -- depart_country_iso_code
              , 'c10': 'VARCHAR' -- depart_subdivision_fips_code
              , 'c11': 'VARCHAR' -- depart_subdivision_iso_code
              , 'c12': 'VARCHAR' -- depart_subdivision_name
              , 'c13': 'VARCHAR' -- depart_wac_oai_id
              , 'c14': 'VARCHAR' -- round_trip_ind
              , 'c15': 'VARCHAR' -- online_ind
              , 'c16': 'VARCHAR' -- fare_credibility_ind
              , 'c17': 'VARCHAR' -- fare_per_smi
              , 'c18': 'VARCHAR' -- reporting_airline_oai_code
              , 'c19': 'VARCHAR' -- passenger_qty
              , 'c20': 'VARCHAR' -- fare_per_person_amount_usd
              , 'c21': 'VARCHAR' -- bulk_fare_ind
              , 'c22': 'VARCHAR' -- distance_smi
              , 'c23': 'VARCHAR' -- distance_group_oai_id
              , 'c24': 'VARCHAR' -- flown_distance_smi
              , 'c25': 'VARCHAR' -- geographic_type_oai_id
              , 'c26': 'VARCHAR' -- filler
            }
      )
  )
-- 1.3. multi-dimensional range interval lookups and projection
select 
      t.itinerary_oai_id
    , t.year_quarter_start_date
    , t.year_quarter_nbr
    , ae.airline_entity_id as reporting_airline_entity_id
    , ae.airline_entity_key as reporting_airline_entity_key
    , ah.airport_history_id as depart_airport_history_id
    , ah.airport_history_key as depart_airport_history_key
    , t.round_trip_fare_ind
    , t.online_purchase_ind
    , t.bulk_fare_ind
    , t.fare_credibility_ind
    , t.distance_group_oai_id
    , t.geographic_type_oai_id
    , t.coupon_qty
    , t.passenger_qty
    , t.distance_smi
    , t.flown_distance_smi
    , t.fare_per_person_usd
    , t.fare_per_mile_usd
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tsmt
from raw_ticket t
left join clean_airlines_lookup ae 
  on t.reporting_airline_oai_code = ae.airline_oai_code
 and t.year_quarter_start_date >= ae.source_from_date 
 and t.year_quarter_start_date < ae.source_thru_date_clean
left join air_oai_dims.airport_history ah
  on t.depart_airport_oai_seq_id = ah.airport_oai_seq_id;

-- 2. process DB1B Coupon data
drop table if exists air_oai_facts.airfare_survey_coupon;
create table air_oai_facts.airfare_survey_coupon as
with 
  -- 2.1. materialize SCD2 CTEs
  clean_airlines_lookup as (
      select *, coalesce(source_thru_date, current_date) as source_thru_date_clean
      from air_oai_dims.airline_entities
      where operating_region_code = 'Domestic'
  ),
  -- 2.2. position-Based Multi-File CSV Streaming
  raw_coupon as (
      select 
            c1::bigint as itinerary_oai_id
          , c3::integer as flight_pass_seq
          , c2::bigint as market_oai_id
          , c5::integer as year_nbr
          , c9::integer as quarter_nbr
          , make_date(c5::integer, (c9::integer - 1) * 3 + 1, 1) as year_quarter_start_date
          , (c5::integer * 10 + c9::integer)::integer as year_quarter_nbr
          , nullif(trim(c10), '')::char(3) as depart_airport_oai_code
          , c7::integer as depart_airport_oai_seq_id
          , nullif(trim(c19), '')::char(3) as arrive_airport_oai_code
          , c17::integer as arrive_airport_oai_seq_id
          , nullif(trim(c25), '')::char(1) as trip_break_code
          , nullif(trim(c26), '')::char(1) as flight_pass_type
          , nullif(trim(c27), '')::varchar(3) as ticketing_airline_oai_code
          , nullif(trim(c28), '')::varchar(3) as operating_airline_oai_code
          , nullif(trim(c29), '')::varchar(3) as reporting_airline_oai_code
          , c4::smallint as flight_pass_qty
          , c30::smallint as passengers_qty
          , nullif(trim(c31), '')::char(1) as airfare_class_code
          , c32::integer as distance_smi
          , c33::smallint as distance_group_oai_id
          , c34::smallint as gateway_ind
          , c35::smallint as itinerary_geographic_type_oai_id
          , c36::smallint as coupon_geographic_type_oai_id
      from read_csv(
            --'s3://src-aviation/DB1B/coupon/CSV/*.csv.gz'
            's3://src-aviation/DB1B/coupon/CSV/Origin_and_Destination_Survey_DB1BCoupon_2025_1.csv.gz'
          , header=true
          , dateformat='%m/%d/%Y %I:%M:%S %p'
          , columns={
                'c1': 'VARCHAR'  -- itinerary_oai_id
              , 'c2': 'VARCHAR'  -- market_oai_id
              , 'c3': 'VARCHAR'  -- flight_pass_seq
              , 'c4': 'VARCHAR'  -- flight_pass_qty
              , 'c5': 'VARCHAR'  -- year_nbr
              , 'c6': 'VARCHAR'  -- depart_airport_oai_id
              , 'c7': 'VARCHAR'  -- depart_airport_oai_seq_id
              , 'c8': 'VARCHAR'  -- depart_city_market_oai_id
              , 'c9': 'VARCHAR'  -- quarter_nbr
              , 'c10': 'VARCHAR' -- depart_airport_oai_code
              , 'c11': 'VARCHAR' -- depart_country_iso_code
              , 'c12': 'VARCHAR' -- depart_state_fips_code
              , 'c13': 'VARCHAR' -- depart_state_iso_code
              , 'c14': 'VARCHAR' -- depart_state_name
              , 'c15': 'VARCHAR' -- depart_world_area_oai_id
              , 'c16': 'VARCHAR' -- arrive_airport_oai_id
              , 'c17': 'VARCHAR' -- arrive_airport_oai_seq_id
              , 'c18': 'VARCHAR' -- arrive_city_market_oai_id
              , 'c19': 'VARCHAR' -- arrive_airport_oai_code
              , 'c20': 'VARCHAR' -- arrive_country_iso_code
              , 'c21': 'VARCHAR' -- arrive_state_fips_code
              , 'c22': 'VARCHAR' -- arrive_state_iso_code
              , 'c23': 'VARCHAR' -- arrive_state_name
              , 'c24': 'VARCHAR' -- arrive_world_area_oai_id
              , 'c25': 'VARCHAR' -- trip_break_code
              , 'c26': 'VARCHAR' -- flight_pass_type
              , 'c27': 'VARCHAR' -- ticketing_airline_oai_code
              , 'c28': 'VARCHAR' -- operating_airline_oai_code
              , 'c29': 'VARCHAR' -- reporting_airline_oai_code
              , 'c30': 'VARCHAR' -- passengers_qty
              , 'c31': 'VARCHAR' -- airfare_class_code
              , 'c32': 'VARCHAR' -- distance_smi
              , 'c33': 'VARCHAR' -- distance_group_id
              , 'c34': 'VARCHAR' -- gateway_ind
              , 'c35': 'VARCHAR' -- itinerary_geo_type_id
              , 'c36': 'VARCHAR' -- coupon_geo_type_id
              , 'c37': 'VARCHAR' -- filler
            }
      )
  )
-- 2.3. multi-dimensional range interval lookups and projection
select 
      c.itinerary_oai_id
    , c.flight_pass_seq
    , c.year_quarter_start_date
    , c.year_quarter_nbr
    , c.market_oai_id
    , aet.airline_entity_id as ticketing_airline_entity_id
    , aet.airline_entity_key as ticketing_airline_entity_key
    , aeo.airline_entity_id as operating_airline_entity_id
    , aeo.airline_entity_key as operating_airline_entity_key
    , aer.airline_entity_id as reporting_airline_entity_id
    , aer.airline_entity_key as reporting_airline_entity_key
    , ahd.airport_history_id as depart_airport_history_id
    , ahd.airport_history_key as depart_airport_history_key
    , aha.airport_history_id as arrive_airport_history_id
    , aha.airport_history_key as arrive_airport_history_key
    , case when c.trip_break_code = 'X' then 1 else 0 end::smallint as trip_break_code
    , c.gateway_ind
    , c.distance_group_oai_id
    , c.airfare_class_code
    , c.itinerary_geographic_type_oai_id
    , c.coupon_geographic_type_oai_id
    , c.flight_pass_type
    , c.flight_pass_qty
    , c.passengers_qty
    , c.distance_smi
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tsmt
from raw_coupon c
left join clean_airlines_lookup aet
  on c.ticketing_airline_oai_code = aet.airline_oai_code
 and c.year_quarter_start_date >= aet.source_from_date 
 and c.year_quarter_start_date < aet.source_thru_date_clean
left join clean_airlines_lookup aeo
  on c.operating_airline_oai_code = aeo.airline_oai_code
 and c.year_quarter_start_date >= aeo.source_from_date 
 and c.year_quarter_start_date < aeo.source_thru_date_clean
left join clean_airlines_lookup aer
  on c.reporting_airline_oai_code = aer.airline_oai_code
 and c.year_quarter_start_date >= aer.source_from_date 
 and c.year_quarter_start_date < aer.source_thru_date_clean
left join air_oai_dims.airport_history ahd
  on c.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on c.arrive_airport_oai_seq_id = aha.airport_oai_seq_id;

-- 3. process DB1B Market data
drop table if exists air_oai_facts.airfare_survey_market;
create table air_oai_facts.airfare_survey_market as
with 
  -- 3.1. materialize SCD2 CTEs
  clean_airlines_lookup as (
      select *, coalesce(source_thru_date, current_date) as source_thru_date_clean
      from air_oai_dims.airline_entities
      where operating_region_code = 'Domestic'
  ),
  -- 3.2. position-Based Multi-File CSV Streaming
  raw_market as (
      select 
            c1::bigint as itinerary_oai_id
          , c2::bigint as market_oai_id
          , c3::smallint as market_coupon_qty
          , c4::integer as year_nbr
          , c5::integer as quarter_nbr
          , make_date(c4::integer, (c5::integer - 1) * 3 + 1, 1) as year_quarter_start_date
          , (c4::integer * 10 + c5::integer)::integer as year_quarter_nbr
          , nullif(trim(c9), '')::char(3) as depart_airport_oai_code
          , c7::integer as depart_airport_oai_seq_id
          , nullif(trim(c18), '')::char(3) as arrive_airport_oai_code
          , c16::integer as arrive_airport_oai_seq_id
          , nullif(trim(c24), '')::varchar(55) as airports_group_oai_code
          , nullif(trim(c25), '')::varchar(55) as world_areas_group_oai_code
          , c26::smallint as ticketing_airline_change_ind
          , nullif(trim(c27), '')::varchar(55) as ticketing_airline_group_code
          , c28::smallint as operating_airline_change_ind
          , nullif(trim(c29), '')::varchar(55) as operating_airline_group_code
          , nullif(trim(c30), '')::varchar(3) as reporting_airline_oai_code
          , nullif(trim(c31), '')::varchar(3) as ticketing_airline_oai_code
          , nullif(trim(c32), '')::varchar(3) as operating_airline_oai_code
          , c33::smallint as bulk_fare_ind
          , c34::smallint as passenger_qty
          , c35::numeric(9,2) as market_fare_amount_usd
          , c36::integer as market_distance_smi
          , c37::smallint as market_distance_group_oai_id
          , c38::integer as market_flown_distance_smi
          , c39::integer as non_stop_distance_smi
          , c40::smallint as itinerary_geograhic_type_oai_id
          , c41::smallint as market_geograhic_type_oai_id
      from read_csv(
            --'s3://src-aviation/DB1B/market/CSV/*.csv.gz'
            's3://src-aviation/DB1B/market/CSV/Origin_and_Destination_Survey_DB1BMarket_2025_1.csv.gz'
          , header=true
          , dateformat='%m/%d/%Y %I:%M:%S %p'
          , columns={
                'c1': 'VARCHAR'  -- itinerary_oai_id
              , 'c2': 'VARCHAR'  -- market_oai_id
              , 'c3': 'VARCHAR'  -- market_coupon_qty
              , 'c4': 'VARCHAR'  -- year_nbr
              , 'c5': 'VARCHAR'  -- quarter_nbr
              , 'c6': 'VARCHAR'  -- depart_airport_oai_id
              , 'c7': 'VARCHAR'  -- depart_airport_oai_seq_id
              , 'c8': 'VARCHAR'  -- depart_market_city_oai_id
              , 'c9': 'VARCHAR'  -- depart_airport_oai_code
              , 'c10': 'VARCHAR' -- depart_country_iso_code
              , 'c11': 'VARCHAR' -- depart_state_fips_code
              , 'c12': 'VARCHAR' -- depart_state_iso_code
              , 'c13': 'VARCHAR' -- depart_state_name
              , 'c14': 'VARCHAR' -- depart_world_area_oai_id
              , 'c15': 'VARCHAR' -- arrive_airport_oai_id
              , 'c16': 'VARCHAR' -- arrive_airport_oai_seq_id
              , 'c17': 'VARCHAR' -- arrive_city_market_oai_id
              , 'c18': 'VARCHAR' -- arrive_airport_oai_code
              , 'c19': 'VARCHAR' -- arrive_country_iso_code
              , 'c20': 'VARCHAR' -- arrive_state_fips_code
              , 'c21': 'VARCHAR' -- arrive_state_iso_code
              , 'c22': 'VARCHAR' -- arrive_state_name
              , 'c23': 'VARCHAR' -- arrive_world_area_oai_id
              , 'c24': 'VARCHAR' -- airports_group_oai_code
              , 'c25': 'VARCHAR' -- world_areas_group_oai_code
              , 'c26': 'VARCHAR' -- ticketing_airline_change_ind
              , 'c27': 'VARCHAR' -- ticketing_airline_group_code
              , 'c28': 'VARCHAR' -- operating_airline_change_ind
              , 'c29': 'VARCHAR' -- operating_airline_group_code
              , 'c30': 'VARCHAR' -- reporting_airline_oai_code
              , 'c31': 'VARCHAR' -- ticketing_airline_oai_code
              , 'c32': 'VARCHAR' -- operating_airline_oai_code
              , 'c33': 'VARCHAR' -- bulk_fare_ind
              , 'c34': 'VARCHAR' -- passenger_qty
              , 'c35': 'VARCHAR' -- market_fare_amt_usd
              , 'c36': 'VARCHAR' -- market_distance_smi
              , 'c37': 'VARCHAR' -- market_distance_group_oai_id
              , 'c38': 'VARCHAR' -- market_flown_distance_smi
              , 'c39': 'VARCHAR' -- non_stop_distance_smi
              , 'c40': 'VARCHAR' -- itinerary_geograhic_type_oai_id
              , 'c41': 'VARCHAR' -- market_geograhic_type_oai_id
              , 'c42': 'VARCHAR' -- filler
            }
      )
  )
-- 3.3. multi-dimensional range interval lookups and projection
select 
      m.itinerary_oai_id
    , m.market_oai_id
    , m.year_quarter_start_date
    , m.year_quarter_nbr
    , aet.airline_entity_id as ticketing_airline_entity_id
    , aet.airline_entity_key as ticketing_airline_entity_key
    , m.ticketing_airline_change_ind
    , m.ticketing_airline_group_code as ticketing_airlines_group_code
    , aeo.airline_entity_id as operating_airline_entity_id
    , aeo.airline_entity_key as operating_airline_entity_key
    , m.operating_airline_change_ind
    , m.operating_airline_group_code as operating_airlines_group_code
    , aer.airline_entity_id as reporting_airline_entity_id
    , aer.airline_entity_key as reporting_airline_entity_key
    , ahd.airport_history_id as depart_airport_history_id
    , ahd.airport_history_key as depart_airport_history_key
    , aha.airport_history_id as arrive_airport_history_id
    , aha.airport_history_key as arrive_airport_history_key
    , m.airports_group_oai_code
    , m.world_areas_group_oai_code
    , m.itinerary_geograhic_type_oai_id
    , m.market_geograhic_type_oai_id
    , m.market_distance_group_oai_id
    , m.bulk_fare_ind
    , m.market_coupon_qty
    , m.passenger_qty
    , m.market_fare_amount_usd
    , m.market_distance_smi
    , m.market_flown_distance_smi
    , m.non_stop_distance_smi
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tsmt
from raw_market m
left join clean_airlines_lookup aet
  on m.ticketing_airline_oai_code = aet.airline_oai_code
 and m.year_quarter_start_date >= aet.source_from_date 
 and m.year_quarter_start_date < aet.source_thru_date_clean
left join clean_airlines_lookup aeo
  on m.operating_airline_oai_code = aeo.airline_oai_code
 and m.year_quarter_start_date >= aeo.source_from_date 
 and m.year_quarter_start_date < aeo.source_thru_date_clean
left join clean_airlines_lookup aer
  on m.reporting_airline_oai_code = aer.airline_oai_code
 and m.year_quarter_start_date >= aer.source_from_date 
 and m.year_quarter_start_date < aer.source_thru_date_clean
left join air_oai_dims.airport_history ahd
  on m.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on m.arrive_airport_oai_seq_id = aha.airport_oai_seq_id;

-- 4. add table constraints
-- airfare_survey_itinerary
alter table air_oai_facts.airfare_survey_itinerary alter itinerary_oai_id set not null;
alter table air_oai_facts.airfare_survey_itinerary alter year_quarter_start_date set not null;
alter table air_oai_facts.airfare_survey_itinerary alter year_quarter_nbr set not null;
alter table air_oai_facts.airfare_survey_itinerary alter reporting_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_itinerary alter reporting_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_itinerary alter depart_airport_history_id set not null;
alter table air_oai_facts.airfare_survey_itinerary alter depart_airport_history_key set not null;
alter table air_oai_facts.airfare_survey_itinerary alter created_by set not null;
alter table air_oai_facts.airfare_survey_itinerary alter created_tmst set not null;
alter table air_oai_facts.airfare_survey_itinerary add constraint airfare_survey_itinerary_pk primary key (itinerary_oai_id, year_quarter_start_date);

-- airfare_survey_coupon
alter table air_oai_facts.airfare_survey_coupon alter itinerary_oai_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter flight_pass_seq set not null;
alter table air_oai_facts.airfare_survey_coupon alter year_quarter_start_date set not null;
alter table air_oai_facts.airfare_survey_coupon alter year_quarter_nbr set not null;
alter table air_oai_facts.airfare_survey_coupon alter market_oai_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter ticketing_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter ticketing_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_coupon alter operating_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter operating_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_coupon alter reporting_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter reporting_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_coupon alter depart_airport_history_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter depart_airport_history_key set not null;
alter table air_oai_facts.airfare_survey_coupon alter arrive_airport_history_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter arrive_airport_history_key set not null;
alter table air_oai_facts.airfare_survey_coupon alter trip_break_code set not null;
alter table air_oai_facts.airfare_survey_coupon alter gateway_ind set not null;
alter table air_oai_facts.airfare_survey_coupon alter distance_group_oai_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter airfare_class_code set not null;
alter table air_oai_facts.airfare_survey_coupon alter itinerary_geographic_type_oai_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter coupon_geographic_type_oai_id set not null;
alter table air_oai_facts.airfare_survey_coupon alter flight_pass_type set not null;
alter table air_oai_facts.airfare_survey_coupon alter flight_pass_qty set not null;
alter table air_oai_facts.airfare_survey_coupon alter passengers_qty set not null;
alter table air_oai_facts.airfare_survey_coupon alter distance_smi set not null;
alter table air_oai_facts.airfare_survey_coupon alter created_by set not null;
alter table air_oai_facts.airfare_survey_coupon alter created_tmst set not null;
alter table air_oai_facts.airfare_survey_coupon add constraint airfare_survey_coupon_pk primary key (itinerary_oai_id, flight_pass_seq, year_quarter_start_date);

-- airfare_survey_market
alter table air_oai_facts.airfare_survey_market alter itinerary_oai_id set not null;
alter table air_oai_facts.airfare_survey_market alter market_oai_id set not null;
alter table air_oai_facts.airfare_survey_market alter year_quarter_start_date set not null;
alter table air_oai_facts.airfare_survey_market alter year_quarter_nbr set not null;
alter table air_oai_facts.airfare_survey_market alter ticketing_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_market alter ticketing_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_market alter ticketing_airline_change_ind set not null;
alter table air_oai_facts.airfare_survey_market alter ticketing_airlines_group_code set not null;
alter table air_oai_facts.airfare_survey_market alter operating_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_market alter operating_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_market alter operating_airline_change_ind set not null;
alter table air_oai_facts.airfare_survey_market alter operating_airlines_group_code set not null;
alter table air_oai_facts.airfare_survey_market alter reporting_airline_entity_id set not null;
alter table air_oai_facts.airfare_survey_market alter reporting_airline_entity_key set not null;
alter table air_oai_facts.airfare_survey_market alter depart_airport_history_id set not null;
alter table air_oai_facts.airfare_survey_market alter depart_airport_history_key set not null;
alter table air_oai_facts.airfare_survey_market alter arrive_airport_history_id set not null;
alter table air_oai_facts.airfare_survey_market alter arrive_airport_history_key set not null;
alter table air_oai_facts.airfare_survey_market alter airports_group_oai_code set not null;
alter table air_oai_facts.airfare_survey_market alter world_areas_group_oai_code set not null;
alter table air_oai_facts.airfare_survey_market alter itinerary_geograhic_type_oai_id set not null;
alter table air_oai_facts.airfare_survey_market alter market_geograhic_type_oai_id set not null;
alter table air_oai_facts.airfare_survey_market alter market_distance_group_oai_id set not null;
alter table air_oai_facts.airfare_survey_market alter bulk_fare_ind set not null;
alter table air_oai_facts.airfare_survey_market alter market_coupon_qty set not null;
alter table air_oai_facts.airfare_survey_market alter passenger_qty set not null;
alter table air_oai_facts.airfare_survey_market alter market_fare_amount_usd set not null;
alter table air_oai_facts.airfare_survey_market alter market_distance_smi set not null;
alter table air_oai_facts.airfare_survey_market alter market_flown_distance_smi set not null;
alter table air_oai_facts.airfare_survey_market alter non_stop_distance_smi set not null;
alter table air_oai_facts.airfare_survey_market alter created_by set not null;
alter table air_oai_facts.airfare_survey_market alter created_tmst set not null;
alter table air_oai_facts.airfare_survey_market add constraint airfare_survey_market_pk primary key (itinerary_oai_id, market_oai_id, year_quarter_start_date);

-- 5. create presentation layer views
-- drop view if exists airlines_ddb.airfare_survey_itinerary_v;
create or replace view airlines_ddb.airfare_survey_itinerary_v as
SELECT itinerary_oai_id, year_quarter_start_date, year_quarter_nbr
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, round_trip_fare_ind, online_purchase_ind, bulk_fare_ind, fare_credibility_ind
	, distance_group_oai_id, geographic_type_oai_id
	, coupon_qty, passenger_qty, distance_smi
	, flown_distance_smi, fare_per_person_usd, fare_per_mile_usd
FROM air_oai_facts.airfare_survey_itinerary;

-- drop view if exists airlines_ddb.airfare_survey_coupon_v;
create or replace view airlines_ddb.airfare_survey_coupon_v as
SELECT itinerary_oai_id, flight_pass_seq, year_quarter_start_date, year_quarter_nbr
    , market_oai_id
	, ticketing_airline_entity_id, ticketing_airline_entity_key
	, operating_airline_entity_id, operating_airline_entity_key
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_history_id, arrive_airport_history_key
	, trip_break_code, gateway_ind
	, distance_group_oai_id, airfare_class_code
	, itinerary_geographic_type_oai_id, coupon_geographic_type_oai_id
	, flight_pass_type, flight_pass_qty
	, passengers_qty, distance_smi
FROM air_oai_facts.airfare_survey_coupon;

-- drop view if exists airlines_ddb.airfare_survey_market_v;
create or replace view airlines_ddb.airfare_survey_market_v as
SELECT itinerary_oai_id, market_oai_id, year_quarter_start_date, year_quarter_nbr
	, ticketing_airline_entity_id, ticketing_airline_entity_key
	, ticketing_airline_change_ind, ticketing_airlines_group_code
	, operating_airline_entity_id, operating_airline_entity_key
	, operating_airline_change_ind, operating_airlines_group_code
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_history_id, arrive_airport_history_key
	, airports_group_oai_code, world_areas_group_oai_code
	, itinerary_geograhic_type_oai_id, market_geograhic_type_oai_id, market_distance_group_oai_id
	, bulk_fare_ind, market_coupon_qty
	, passenger_qty, market_fare_amount_usd, market_distance_smi
	, market_flown_distance_smi, non_stop_distance_smi
FROM air_oai_facts.airfare_survey_market;
