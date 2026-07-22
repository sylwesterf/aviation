-- DB1B (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BTicket
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BCoupon
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BMarket
-- https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFI&Yv0x=D

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. process DB1B Ticket data
--  1.1. extraction stage (S3 CSV to multipart db1b_ticket_raw_extract/*.parquet)
--  1.2. create and load air_oai_facts.airfare_survey_itinerary
-- 2. process DB1B Coupon data
--  2.1. extraction stage (S3 CSV to multipart db1b_coupon_raw_extract/*.parquet)
--  2.2. create and load air_oai_facts.airfare_survey_coupon
-- 3. process DB1B Market data
--  3.1. extraction stage (S3 CSV to multipart db1b_market_raw_extract/*.parquet)
--  3.2. create and load air_oai_facts.airfare_survey_market
-- 4. add table constraints
-- 5. create presentation layer views
----------------------------------------------------

-- 1. process DB1B Ticket data
-- 1.1. extraction stage (no joins, low memory profile, multipart)
copy (
    select 
          itinerary_oai_id::bigint as itinerary_oai_id
        , year_nbr::integer as year_nbr
        , quarter_nbr::integer as quarter_nbr
        , make_date(year_nbr::integer, (quarter_nbr::integer - 1) * 3 + 1, 1) as year_quarter_start_date
        , (year_nbr * 10 + quarter_nbr)::integer as year_quarter_nbr
        , depart_airport_oai_code::char(3) as depart_airport_oai_code
        , depart_airport_oai_seq_id::integer as depart_airport_oai_seq_id
        , nullif(trim(reporting_airline_oai_code), '')::varchar(3) as reporting_airline_oai_code
        , round_trip_ind::smallint as round_trip_fare_ind
        , online_ind::smallint as online_purchase_ind
        , bulk_fare_ind::smallint as bulk_fare_ind
        , fare_credibility_ind::smallint as fare_credibility_ind
        , distance_group_oai_id::smallint as distance_group_oai_id
        , geographic_type_oai_id::smallint as geographic_type_oai_id
        , coupon_qty::smallint as coupon_qty
        , passenger_qty::smallint as passenger_qty
        , distance_smi::integer as distance_smi
        , flown_distance_smi::integer as flown_distance_smi
        , fare_per_person_amount_usd::integer as fare_per_person_usd
        , fare_per_smi::numeric(10,5) as fare_per_mile_usd
    from read_csv('s3://src-aviation/DB1B/ticket/CSV/*.csv.gz', union_by_name=true)
) to 'db1b_ticket_raw_extract' (format 'parquet', compression 'zstd', per_thread_output true);

-- 1.2. create and load air_oai_facts.airfare_survey_itinerary
drop table if exists air_oai_facts.airfare_survey_itinerary;
create table air_oai_facts.airfare_survey_itinerary as
with filtered_airline_entities as (
    select airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    from air_oai_dims.airline_entities
    where operating_region_code = 'Domestic'
),
raw_ticket as (
    select * from read_parquet('db1b_ticket_raw_extract/*.parquet')
)
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
left join filtered_airline_entities ae 
  on t.reporting_airline_oai_code = ae.airline_oai_code
 and t.year_quarter_start_date >= ae.source_from_date 
 and t.year_quarter_start_date < coalesce(ae.source_thru_date, current_date)
left join air_oai_dims.airport_history ah
  on t.depart_airport_oai_seq_id = ah.airport_oai_seq_id;

-- 2. process DB1B Coupon data
-- 2.1. extraction stage (no joins, low memory profile, multipart)
copy (
    select 
          itinerary_oai_id::bigint as itinerary_oai_id
        , flight_pass_seq::integer as flight_pass_seq
        , market_oai_id::bigint as market_oai_id
        , year_nbr::integer as year_nbr
        , quarter_nbr::integer as quarter_nbr
        , make_date(year_nbr::integer, (quarter_nbr::integer - 1) * 3 + 1, 1) as year_quarter_start_date
        , (year_nbr * 10 + quarter_nbr)::integer as year_quarter_nbr
        , depart_airport_oai_code::char(3) as depart_airport_oai_code
        , depart_airport_oai_seq_id::integer as depart_airport_oai_seq_id
        , arrive_airport_oai_code::char(3) as arrive_airport_oai_code
        , arrive_airport_oai_seq_id::integer as arrive_airport_oai_seq_id
        , nullif(trim(trip_break_code), '')::char(1) as trip_break_code
        , nullif(trim(flight_pass_type), '')::char(1) as flight_pass_type
        , nullif(trim(ticketing_airline_oai_code), '')::varchar(3) as ticketing_airline_oai_code
        , nullif(trim(operating_airline_oai_code), '')::varchar(3) as operating_airline_oai_code
        , nullif(trim(reporting_airline_oai_code), '')::varchar(3) as reporting_airline_oai_code
        , flight_pass_qty::smallint as flight_pass_qty
        , passengers_qty::smallint as passengers_qty
        , nullif(trim(airfare_class_code), '')::char(1) as airfare_class_code
        , distance_smi::integer as distance_smi
        , distance_group_id::smallint as distance_group_oai_id
        , gateway_ind::smallint as gateway_ind
        , itinerary_geo_type_id::smallint as itinerary_geographic_type_oai_id
        , coupon_geo_type_id::smallint as coupon_geographic_type_oai_id
    from read_csv('s3://src-aviation/DB1B/coupon/CSV/*.csv.gz', union_by_name=true)
) to 'db1b_coupon_raw_extract' (format 'parquet', compression 'zstd', per_thread_output true);

-- 2.2. create and load air_oai_facts.airfare_survey_coupon
drop table if exists air_oai_facts.airfare_survey_coupon;
create table air_oai_facts.airfare_survey_coupon as
with filtered_airline_entities as (
    select airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    from air_oai_dims.airline_entities
    where operating_region_code = 'Domestic'
),
raw_coupon as (
    select * from read_parquet('db1b_coupon_raw_extract/*.parquet')
)
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
left join filtered_airline_entities aet
  on c.ticketing_airline_oai_code = aet.airline_oai_code
 and c.year_quarter_start_date >= aet.source_from_date 
 and c.year_quarter_start_date < coalesce(aet.source_thru_date, current_date)
left join filtered_airline_entities aeo
  on c.operating_airline_oai_code = aeo.airline_oai_code
 and c.year_quarter_start_date >= aeo.source_from_date 
 and c.year_quarter_start_date < coalesce(aeo.source_thru_date, current_date)
left join filtered_airline_entities aer
  on c.reporting_airline_oai_code = aer.airline_oai_code
 and c.year_quarter_start_date >= aer.source_from_date 
 and c.year_quarter_start_date < coalesce(aer.source_thru_date, current_date)
left join air_oai_dims.airport_history ahd
  on c.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on c.arrive_airport_oai_seq_id = aha.airport_oai_seq_id;

-- 3. process DB1B Market data
-- 3.1. extraction stage (no joins, low memory profile, multipart)
copy (
    select 
          itinerary_oai_id::bigint as itinerary_oai_id
        , market_oai_id::bigint as market_oai_id
        , market_coupon_qty::smallint as market_coupon_qty
        , year_nbr::integer as year_nbr
        , quarter_nbr::integer as quarter_nbr
        , make_date(year_nbr::integer, (quarter_nbr::integer - 1) * 3 + 1, 1) as year_quarter_start_date
        , (year_nbr * 10 + quarter_nbr)::integer as year_quarter_nbr
        , depart_airport_oai_code::char(3) as depart_airport_oai_code
        , depart_airport_oai_seq_id::integer as depart_airport_oai_seq_id
        , arrive_airport_oai_code::char(3) as arrive_airport_oai_code
        , arrive_airport_oai_seq_id::integer as arrive_airport_oai_seq_id
        , nullif(trim(airports_group_oai_code), '')::varchar(55) as airports_group_oai_code
        , nullif(trim(world_areas_group_oai_code), '')::varchar(55) as world_areas_group_oai_code
        , ticketing_airline_change_ind::smallint as ticketing_airline_change_ind
        , nullif(trim(ticketing_airline_group_code), '')::varchar(55) as ticketing_airline_group_code
        , operating_airline_change_ind::smallint as operating_airline_change_ind
        , nullif(trim(operating_airline_group_code), '')::varchar(55) as operating_airline_group_code
        , nullif(trim(reporting_airline_oai_code), '')::varchar(3) as reporting_airline_oai_code
        , nullif(trim(ticketing_airline_oai_code), '')::varchar(3) as ticketing_airline_oai_code
        , nullif(trim(operating_airline_oai_code), '')::varchar(3) as operating_airline_oai_code
        , bulk_fare_ind::smallint as bulk_fare_ind
        , passenger_qty::smallint as passenger_qty
        , market_fare_amt_usd::numeric(9,2) as market_fare_amount_usd
        , market_distance_smi::integer as market_distance_smi
        , market_distance_group_oai_id::smallint as market_distance_group_oai_id
        , market_flown_distance_smi::integer as market_flown_distance_smi
        , non_stop_distance_smi::integer as non_stop_distance_smi
        , itinerary_geograhic_type_oai_id::smallint as itinerary_geograhic_type_oai_id
        , market_geograhic_type_oai_id::smallint as market_geograhic_type_oai_id
    from read_csv('s3://src-aviation/DB1B/market/CSV/*.csv.gz', union_by_name=true)
) to 'db1b_market_raw_extract' (format 'parquet', compression 'zstd', per_thread_output true);

-- 3.2. create and load air_oai_facts.airfare_survey_market
drop table if exists air_oai_facts.airfare_survey_market;
create table air_oai_facts.airfare_survey_market as
with filtered_airline_entities as (
    select airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    from air_oai_dims.airline_entities
    where operating_region_code = 'Domestic'
),
raw_market as (
    select * from read_parquet('db1b_market_raw_extract/*.parquet')
)
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
left join filtered_airline_entities aet
  on m.ticketing_airline_oai_code = aet.airline_oai_code
 and m.year_quarter_start_date >= aet.source_from_date 
 and m.year_quarter_start_date < coalesce(aet.source_thru_date, current_date)
left join filtered_airline_entities aeo
  on m.operating_airline_oai_code = aeo.airline_oai_code
 and m.year_quarter_start_date >= aeo.source_from_date 
 and m.year_quarter_start_date < coalesce(aeo.source_thru_date, current_date)
left join filtered_airline_entities aer
  on m.reporting_airline_oai_code = aer.airline_oai_code
 and m.year_quarter_start_date >= aer.source_from_date 
 and m.year_quarter_start_date < coalesce(aer.source_thru_date, current_date)
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
