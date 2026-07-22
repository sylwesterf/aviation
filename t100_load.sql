-- T100 (Market and Segment) (US DoT data) 
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Market (All Carriers)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Statistics (Form 41 Traffic)- All Carriers Database > T-100 Segment (All Carriers)	
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EEE&QO_anzr=Nv4%FDPn44vr4%FDf6n6v56vp5%FD%FLS14z%FDHE%FDg4nssvp%FM-%FDNyy%FDPn44vr45&QO_fu146_anzr=Nv4%FDPn44vr45

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month)
-- 1. create and load air_oai_facts.airline_traffic_market (use CTEs to pre-process the data; streaming ~500MB of compressed csv files)
-- 2. create and load air_oai_facts.airline_traffic_segment (use CTEs to pre-process the data; streaming ~300MB of compressed csv files)
-- 3. create and load air_oai_dims.aircraft_configurations based on air_oai_facts.airline_traffic_segment
-- 4. create and load air_oai_dims.airline_service_classes based on air_oai_facts.airline_traffic_market
-- 5. add table constraints
-- 6. create presentation layer views
----------------------------------------------------

-- 1. create and load air_oai_facts.airline_traffic_market
drop table if exists air_oai_facts.airline_traffic_market;
create table air_oai_facts.airline_traffic_market as
with raw_market as (
    select 
          year_nbr
        , month_nbr
        , service_class_code
        , airline_usdot_id
        , airline_oai_code
        , entity_unique_oai_code
        , depart_airport_oai_id
        , depart_airport_oai_code
        , arrive_airport_oai_id
        , arrive_airport_oai_code
        , data_source_code
        , passengers_qty
        , freight_lbr
        , mail_lbr
        , make_date(year_nbr::integer, month_nbr::integer, 1) as anchor_date
        , (year_nbr * 100 + month_nbr)::integer as year_month_nbr
    from read_csv('s3://src-aviation/T100/market/CSV/*.csv.gz')
),
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
    left join air_oai_dims.airline_entities ae
      on f.airline_usdot_id = ae.airline_usdot_id
     and f.airline_oai_code = ae.airline_oai_code
     and f.entity_unique_oai_code = ae.entity_unique_oai_code
     and f.anchor_date >= ae.source_from_date
     and f.anchor_date < case when ae.source_thru_date is null then current_date else ae.source_thru_date end
    left join air_oai_dims.airport_history h1
      on f.depart_airport_oai_id = h1.airport_oai_id
     and f.anchor_date >= h1.effective_from_date
     and f.anchor_date < case when h1.effective_thru_date is null then current_date else h1.effective_thru_date end
    left join air_oai_dims.airport_history h2
      on f.arrive_airport_oai_id = h2.airport_oai_id
     and f.anchor_date >= h2.effective_from_date
     and f.anchor_date < case when h2.effective_thru_date is null then current_date else h2.effective_thru_date end
)
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
with raw_segment as (
    select 
          year_nbr
        , month_nbr
        , service_class_code
        , airline_usdot_id
        , airline_oai_code
        , entity_unique_oai_code
        , depart_airport_oai_id
        , depart_airport_oai_code
        , depart_country_iso_code
        , arrive_airport_oai_id
        , arrive_airport_oai_code
        , arrive_country_iso_code
        , aircraft_type_oai_nbr
        , aircraft_configuration_id
        , data_source_code
        , passengers_qty
        , freight_lbr
        , mail_lbr
        , available_seat_qty
        , scheduled_departures_qty
        , performed_departures_qty
        , ramp_to_ramp_min
        , air_time_min
        , make_date(year_nbr::integer, month_nbr::integer, 1) as anchor_date
        , (year_nbr * 100 + month_nbr)::integer as year_month_nbr
    from read_csv('s3://src-aviation/T100/segment/CSV/*.csv.gz')
),
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
          when airline_oai_code = '2HQ' is not null and airline_usdot_id is null then 21712
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
          when airline_oai_code = '2HQ' is not null and airline_usdot_id is null
            and depart_country_iso_code = 'US' and arrive_country_iso_code = 'US' then '01200'
          when airline_oai_code = '2HQ' is not null and airline_usdot_id is null
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
    left join air_oai_dims.airline_entities ae
      on f.airline_usdot_id = ae.airline_usdot_id
     and f.airline_oai_code = ae.airline_oai_code
     and f.entity_unique_oai_code = ae.entity_unique_oai_code
     and f.anchor_date >= ae.source_from_date
     and f.anchor_date < case when ae.source_thru_date is null then current_date else ae.source_thru_date end
    left join air_oai_dims.airport_history h1
      on f.depart_airport_oai_id = h1.airport_oai_id
     and f.anchor_date >= h1.effective_from_date
     and f.anchor_date < case when h1.effective_thru_date is null then current_date else h1.effective_thru_date end
    left join air_oai_dims.airport_history h2
      on f.arrive_airport_oai_id = h2.airport_oai_id
     and f.anchor_date >= h2.effective_from_date
     and f.anchor_date < case when h2.effective_thru_date is null then current_date else h2.effective_thru_date end
)
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
  and aircraft_type_oai_nbr is not null 
  and aircraft_configuration_ref is not null
group by year_month_nbr, service_class_code, airline_entity_key, depart_airport_history_key, arrive_airport_history_key, aircraft_type_oai_nbr, aircraft_configuration_ref;


-- 3. create and load air_oai_dims.aircraft_configurations
drop table if exists air_oai_dims.aircraft_configurations;
create table air_oai_dims.aircraft_configurations as
select f.aircraft_configuration_ref::char(3) as aircraft_configuration_ref
     , max(case f.aircraft_configuration_ref 
			when 'CMB' then 'Combination Freight and Passenger, Main Deck'
            when 'FRT' then 'Freight Only, Main Deck'
            when 'PAX' then 'Passenger Only, Main Deck'
            when 'SEA' then 'Seaplane'
            else null end)::varchar(255) as aircraft_configuration_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp as updated_tmst
from air_oai_facts.airline_traffic_segment f
group by 1 order by 1;


-- 4. create and load air_oai_dims.airline_service_classes
drop table if exists air_oai_dims.airline_service_classes;
create table air_oai_dims.airline_service_classes as
select f.service_class_code::char(1) as service_class_code
     , max(case when f.service_class_code in ('F','G') then 1 else 0 end)::smallint as scheduled_ind
     , max(case when f.service_class_code in ('L','P') then 1 else 0 end)::smallint as chartered_ind
     , max(case f.service_class_code 
			when 'F' then 'Scheduled Passenger / Cargo Service'
            when 'G' then 'Scheduled CAll Cargo Service'
            when 'L' then 'Non-Scheduled Civilian Passenger / Cargo Service'
            when 'P' then 'Non-Scheduled Civilian All Cargo Service'
            else null end)::varchar(255) as service_class_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp as created_ts
     , null::varchar(32) as updated_by
     , null::timestamp as updated_tmst
from air_oai_facts.airline_traffic_market f
group by 1 order by 1;


-- 5. add table constraints
-- aircraft_configurations
alter table air_oai_dims.aircraft_configurations alter aircraft_configuration_ref set not null;
alter table air_oai_dims.aircraft_configurations alter created_by set not null;
alter table air_oai_dims.aircraft_configurations alter created_ts set not null;
alter table air_oai_dims.aircraft_configurations add constraint aircraft_configurations_pk primary key (aircraft_configuration_ref);

-- airline_service_classes
alter table air_oai_dims.airline_service_classes alter service_class_code set not null;
alter table air_oai_dims.airline_service_classes alter scheduled_ind set not null;
alter table air_oai_dims.airline_service_classes alter chartered_ind set not null;
alter table air_oai_dims.airline_service_classes alter created_by set not null;
alter table air_oai_dims.airline_service_classes alter created_ts set not null;
alter table air_oai_dims.airline_service_classes add constraint airline_service_classes_pk primary key (service_class_code);

-- airline_traffic_market
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
	, scheduled_ind
	, chartered_ind
	, service_class_descr
FROM air_oai_dims.airline_service_classes;

-- drop view if exists airlines_ddb.airline_traffic_market_v;
create or replace view airlines_ddb.airline_traffic_market_v as
SELECT airline_traffic_market_key, year_month_nbr
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, service_class_code, data_source_code
	, passengers_qty, freight_kgm, mail_kgm
FROM air_oai_facts.airline_traffic_market;

-- drop view if exists airlines_ddb.airline_traffic_segment_v;
create or replace view airlines_ddb.airline_traffic_segment_v as
SELECT airline_traffic_segment_key, year_month_nbr, service_class_code
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, aircraft_type_oai_nbr, aircraft_configuration_ref
	, data_source_code
	, scheduled_departures_qty, performed_departures_qty
	, available_seat_qty, passengers_qty, freight_kgm, mail_kgm
	, ramp_to_ramp_min, air_time_min
FROM air_oai_facts.airline_traffic_segment;
