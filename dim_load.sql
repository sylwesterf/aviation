-- Aviation Support/Dimension Tables (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Aviation Support Tables
-- https://transtats.bts.gov/Tables.asp?QO_VQ=IMI&QO_anzr=N8vn6v10%FDf722146%FDgnoyr5&QO_fu146_anzr=N8vn6v10%FDf722146%FDgnoyr5

----------------------------------------------------
-- STEPS:
-- 0. download and unzip individual pre-zipped data files: AircraftTypes, Carrier Decode, Master Coordinate, World Area Codes
-- 1. create and load air_oai_dims.aircraft_types
-- 2. create and load air_oai_dims.world_areas
-- 3. create and load air_oai_dims.airline_entities
-- 4. create and load air_oai_dims.airport_history
-- 5. create and load air_oai_dims.aircraft_type_groups
-- 6. create and load air_oai_dims.airline_entity_new_groups
-- 7. create and load air_oai_dims.airline_entity_legacy_groups
-- 8. create and load air_oai_dims.airline_geographic_types
-- 9. create and load air_oai_dims.airfare_classes
-- 10. create and load air_oai_dims.airline_traffic_data_sources
-- 11. add table constraints
-- 12. create presentation layer views
----------------------------------------------------

-- 1. create and load air_oai_dims.aircraft_types 
drop table if exists air_oai_dims.aircraft_types;
create table air_oai_dims.aircraft_types as
select 
	aircraft_type_oai_nbr::smallint as aircraft_type_oai_nbr
	, aircraft_group_oai_nbr::smallint as aircraft_group_oai_nbr
	, aircraft_oai_type::varchar(55) as aircraft_oai_type
	, case when manufacturer_name is null then 'GENERIC' else manufacturer_name end::varchar(55) as manufacturer_name
	, aircraft_type_long_name::varchar(55) as aircraft_type_long_name
	, aircraft_type_brief_name::varchar(55) as aircraft_type_brief_name
	, aircraft_type_from_date::date as aircraft_type_from_date
	, aircraft_type_thru_date::date as aircraft_type_thru_date
	, current_user::varchar(32) as created_by
	, current_timestamp::timestamp as created_tmst
	, null::varchar(32) as updated_by
	, null::timestamp as updated_tsmt
from read_csv('s3://src-aviation/DIMS/CSV/T_AIRCRAFT_TYPES.csv');


-- 2. create and load air_oai_dims.world_areas 
drop table if exists air_oai_dims.world_areas;
create table air_oai_dims.world_areas as
select 
	world_area_oai_seq_id::integer as world_area_oai_seq_id
	, md5(world_area_oai_id::varchar ||'~'|| effective_from_date::varchar)::char(32) as world_area_key
	, world_area_oai_id::smallint as world_area_oai_id
	, effective_from_date::date as effective_from_date
	, effective_thru_date::date as effective_thru_date
	, world_area_latest_ind::smallint as world_area_latest_ind
	, world_area_name::varchar(125) as world_area_name
	, world_region_name::varchar(125) as world_region_name
	, subdivision_iso_code::varchar(10) as subdivision_iso_code
	, subdivision_fips_code::varchar(10) as subdivision_fips_code
	, subdivision_name::varchar(75) as subdivision_name
	, country_iso_code::char(2) as country_iso_code
	, country_short_name::varchar(75) as country_short_name
	, country_type_descr::varchar(75) as country_type_descr
	, sovereign_country_name::varchar(75) as sovereign_country_name
	, capital_city_name::varchar(75) as capital_city_name
	, comments_text::varchar(555) as world_area_comments_text
	, current_user::varchar(32) as created_by
	, current_timestamp::timestamp as created_tmst
	, null::varchar(32) as updated_by
	, null::timestamp as updated_tsmt
from read_csv('s3://src-aviation/DIMS/CSV/T_WAC_COUNTRY_STATE.csv');


-- 3. create and load air_oai_dims.airline_entities 
drop table if exists air_oai_dims.airline_entities;
create table air_oai_dims.airline_entities as
with raw_data as (
    select * from read_csv('s3://src-aviation/DIMS/CSV/T_CARRIER_DECODE.csv')
),
combined as (
    select 
        airline_usdot_id::smallint as airline_usdot_id
        , airline_oai_code::varchar(10) as airline_oai_code
        , entity_oai_code::varchar(10) as entity_oai_code
        , airline_name::varchar(125) as airline_name
        , airline_unique_oai_code::varchar(10) as airline_unique_oai_code
        , entity_unique_oai_code::varchar(10) as entity_unique_oai_code
        , airline_unique_name::varchar(125) as airline_unique_name
        , world_area_oai_id::smallint as world_area_oai_id
        , airline_old_group_nbr::smallint as airline_old_group_nbr
        , airline_new_group_nbr::smallint as airline_new_group_nbr
        , operating_region_code::varchar(25) as operating_region_code
        , source_from_date::date as source_from_date
        , source_thru_date::date as source_thru_date
    from raw_data
    where airline_oai_code != '3KQ'
    union all
    select 
        max(airline_usdot_id)::smallint as airline_usdot_id
        , airline_oai_code::varchar(10) as airline_oai_code
        , entity_oai_code::varchar(10) as entity_oai_code
        , max(airline_name)::varchar(125) as airline_name
        , max(airline_unique_oai_code)::varchar(10) as airline_unique_oai_code
        , max(entity_unique_oai_code)::varchar(10) as entity_unique_oai_code
        , max(airline_unique_name)::varchar(125) as airline_unique_name
        , max(world_area_oai_id)::smallint as world_area_oai_id
        , max(airline_old_group_nbr)::smallint as airline_old_group_nbr
        , max(airline_new_group_nbr)::smallint as airline_new_group_nbr
        , max(operating_region_code)::varchar(25) as operating_region_code
        , source_from_date::date as source_from_date
        , max(source_thru_date)::date as source_thru_date
    from raw_data
    where airline_oai_code = '3KQ'
    group by airline_oai_code, entity_oai_code, source_from_date
)
select 
    row_number() over (order by airline_usdot_id, airline_oai_code, entity_oai_code, source_from_date)::smallint as airline_entity_id
    , md5(airline_oai_code ||'~'|| entity_oai_code ||'~'|| source_from_date::varchar)::char(32) as airline_entity_key
    , airline_usdot_id
    , airline_oai_code
    , entity_oai_code
    , airline_name
    , airline_unique_oai_code
    , entity_unique_oai_code
    , airline_unique_name
    , world_area_oai_id
    , null::integer as world_area_oai_seq_id
    , airline_old_group_nbr
    , airline_new_group_nbr
    , operating_region_code
    , source_from_date
    , source_thru_date
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_tmst
    , null::varchar(32) as updated_by
    , null::timestamp as updated_tsmt
from combined
order by airline_usdot_id, airline_oai_code, entity_oai_code, source_from_date;


-- 4. create and load air_oai_dims.airport_history 
drop table if exists air_oai_dims.airport_history;
create table air_oai_dims.airport_history as
with master_cord as (
    select * from read_csv('s3://src-aviation/DIMS/CSV/T_MASTER_CORD.csv')
)
select 
	row_number() over (order by m.airport_oai_code, m.airport_effective_from_date)::integer as airport_history_id
	, md5(upper(m.airport_oai_code)||'~'||m.airport_effective_from_date::varchar)::char(32) as airport_history_key
	, m.airport_oai_code::varchar(3) as airport_oai_code
	, m.airport_effective_from_date::date as effective_from_date
	, m.airport_effective_thru_date::date as effective_thru_date
	, m.airport_closed_ind::smallint as airport_closed_ind
	, m.airport_latest_ind::smallint as airport_latest_ind
	, m.airport_oai_seq_id::integer as airport_oai_seq_id
	, m.airport_oai_id::integer as airport_oai_id
	, m.airport_display_name::varchar(125) as airport_display_name
	, m.city_full_display_name::varchar(125) as city_full_display_name
	, m.airport_world_area_oai_seq_id::integer as airport_world_area_oai_seq_id
	, m.airport_world_area_oai_id::integer as airport_world_area_oai_id
	, b.world_area_key::char(32) as airport_world_area_key
	, case when length(m.utc_local_time_variation) = 0 then null else m.utc_local_time_variation end::char(5) as utc_local_time_variation
	, null::varchar(100) as time_zone_name
	, m.market_city_oai_seq_id::integer as market_city_oai_seq_id
	, m.market_city_oai_id::integer as market_city_oai_id
	, m.market_city_full_display_name::varchar(75) as market_city_full_display_name
	, m.market_city_world_area_oai_seq_id::integer as market_city_world_area_oai_seq_id
	, m.market_city_world_area_oai_id::integer as market_city_world_area_oai_id
	, c.world_area_key::char(32) as market_city_world_area_key
	, m.subdivision_iso_code::varchar(10) as subdivision_iso_code
	, m.subdivision_fips_code::varchar(10) as subdivision_fips_code
	, m.subdivision_name::varchar(75) as subdivision_name
	, m.country_iso_code::varchar(10) as country_iso_code
	, m.country_name::varchar(75) as country_name
	, m.latitude_decimal_nbr::numeric(9,7) as latitude_decimal_nbr
	, m.longitude_decimal_nbr::numeric(10,7) as longitude_decimal_nbr
	, case when m.latitude_decimal_nbr is not null and m.longitude_decimal_nbr is not null 
	      then ST_Point(m.longitude_decimal_nbr, m.latitude_decimal_nbr)
	      else null end as point_geom
	, current_user::varchar(32) as created_by
	, current_timestamp::timestamp as created_tmst
	, null::varchar(32) as updated_by
	, null::timestamp as updated_tsmt
from master_cord m
left join air_oai_dims.world_areas b
  on m.airport_world_area_oai_id = b.world_area_oai_id
 and m.airport_world_area_oai_seq_id = b.world_area_oai_seq_id
left join air_oai_dims.world_areas c
  on m.market_city_world_area_oai_id = c.world_area_oai_id
 and m.market_city_world_area_oai_seq_id = c.world_area_oai_seq_id;

-- 4.2 update the time zone boundaries in air_oai_dims.airport_history 
update air_oai_dims.airport_history
set	
	time_zone_name = c.time_zone_name
	, updated_by = current_user
	, updated_tsmt = current_timestamp
from (
select a.airport_history_id, a.airport_oai_code, a.effective_from_date, b.time_zone_name 
from (select airport_history_id, airport_oai_code, effective_from_date, point_geom 
      from air_oai_dims.airport_history where time_zone_name is null) a
cross join (select gid, tzid as time_zone_name, geom as time_zone_geom from public.timezone_boundaries) b
where ST_Contains(b.time_zone_geom, a.point_geom) is true
) c
where air_oai_dims.airport_history.airport_history_id = c.airport_history_id
and air_oai_dims.airport_history.time_zone_name is null;


-- 5. create and load air_oai_dims.aircraft_type_groups 
drop table if exists air_oai_dims.aircraft_type_groups;
create table air_oai_dims.aircraft_type_groups as
select distinct coalesce( aircraft_group_oai_nbr, -1)::smallint as aircraft_group_oai_nbr
  ,case aircraft_group_oai_nbr
    when 0 then 'Piston, 1 Engine'
    when 1 then 'Piston, 2 Engines'
    when 2 then 'Piston, 3-4 Engine'
    when 3 then 'Helicopter/STOL'
    when 4 then 'Turbo-Prop, 1-2 Engines'
    when 5 then 'Turbo-Prop, 4 Engines'
    when 6 then 'Jet, 2 Engines'
    when 7 then 'Jet, 3 Engines'
    when 8 then 'Jet, 4-6 Engines'
    when 9 then 'Expenses'
    else 'UNK'
  end::varchar(55) as descr
  ,case aircraft_group_oai_nbr
    when 0 then 'Piston, 1-Engine/Combined Single Engine (Piston/Turbine)'
    when 1 then 'Piston, 2-Engine'
    when 2 then 'Piston, 3-Engine/4-Engine'
    when 3 then 'Helicopter/Short-Take-Off-Landing'
    when 4 then 'TTurbo-Prop, 1-Engine/2-Engine'
    when 5 then 'Turbo-Prop, 4-Engine'
    when 6 then 'Jet, 2-Engines'
    when 7 then 'Jet, 3 Engines'
    when 8 then 'Jet, 4-Engine/6-Engine'
    when 9 then 'Used for capturing expenses not attributed to specific aircraft types'
    else 'UNK'
  end::varchar(255) as long_descr
  ,current_user::varchar(32) as created_by
  ,current_timestamp::timestamp as created_ts
from air_oai_dims.aircraft_types;


-- 6. create and load air_oai_dims.airline_entity_new_groups 
drop table if exists air_oai_dims.airline_entity_new_groups;
create table air_oai_dims.airline_entity_new_groups as
select distinct coalesce(airline_new_group_nbr, -1)::smallint as airline_new_group_nbr
       ,CASE airline_new_group_nbr
            WHEN 0 THEN 'Foreign'
            WHEN 1 THEN 'Large Regional'
            WHEN 2 THEN 'National'
            WHEN 3 THEN 'Major'
            WHEN 4 THEN 'Medium'
            WHEN 5 THEN 'Small, Certified'
            WHEN 6 THEN 'Commuter, Large'
            WHEN 7 THEN 'All Cargo'
            WHEN 9 THEN 'Commuter, Essential'
            ELSE 'UNK'
        END::varchar(55) AS descr
        ,CASE airline_new_group_nbr
            WHEN 0 THEN 'Foreign Carriers'
            WHEN 1 THEN 'Large Regional Carriers (carriers with annual revenue of $20 million to $100 million))'
            WHEN 2 THEN 'National Carriers (carriers with annual revenue over 100 milion to 1 billion)'
            WHEN 3 THEN 'Major Carriers (carriers with annual revenue over $1 billion'
            WHEN 4 THEN 'Medium Regional Carriers (carriers with annual revenue under $20 million)'
            WHEN 5 THEN 'Small Certificated Carriers (carrier holding certificate issued under 49 U.S.C. section 41101 and operating aircraft designed to have a maximum seating capacity of 60 or less seat or a maximum payload of 18,000 pounds or less.)'
            WHEN 6 THEN 'Commuter Carriers (air taxi operator which performs at least five round trips per week between two or more points and publishes flight schedules which specify the times, days of the weeks and plans between which such flights are performed.'
            WHEN 7 THEN 'All Cargo Carriers operating under cerificates issued under 49 U.S.C. section 41103'
            WHEN 9 THEN 'Commuter Carriers (Air Taxi providing Essential Air Service)'
            ELSE 'UNK'
        END::varchar(255) AS long_descr
        ,current_user::varchar(32) as created_by
        ,current_timestamp::timestamp as created_ts
from air_oai_dims.airline_entities;


-- 7. create and load air_oai_dims.airline_entity_legacy_groups 
drop table if exists air_oai_dims.airline_entity_legacy_groups;
create table air_oai_dims.airline_entity_legacy_groups as
select distinct coalesce(airline_old_group_nbr, -1)::smallint as airline_old_group_nbr
      ,CASE airline_old_group_nbr
          WHEN 0 THEN 'International'
          WHEN 1 THEN 'Regional'
          WHEN 2 THEN 'National'
          WHEN 3 THEN 'Major'
          WHEN 7 THEN 'All Cargo'
          ELSE 'UNK'
      END::varchar(55) AS descr
      ,CASE airline_old_group_nbr
          WHEN 0 THEN 'International Carriers'
          WHEN 1 THEN 'Regional Carriers (including Large, Medium, Commuter, Small Certified)'
          WHEN 2 THEN 'National Carriers'
          WHEN 3 THEN 'Major Carriers'
          WHEN 7 THEN 'Domestic Only - All Cargo Carriers'
          ELSE 'UN'
      END::varchar(255) AS long_descr
      ,current_user::varchar(32) as created_by
      ,current_timestamp::timestamp as created_ts
from air_oai_dims.airline_entities;


-- 8. create and load air_oai_dims.airline_geographic_types
drop table if exists air_oai_dims.airline_geographic_types;
create table air_oai_dims.airline_geographic_types as
select 0::smallint as geograhic_type_oai_id, 'International'::varchar(35) as descr, 'International travel between indepedent soverign states.'::varchar(255) as long_descr union all
select 1::smallint as geograhic_type_oai_id, 'Domestic, Global'::varchar(35) as descr, 'Domestic Non-contiguous (Includes Hawaii, Alaska and Territories)'::varchar(255) as long_descr union all
select 2::smallint as geograhic_type_oai_id, 'Domestic, Lower48'::varchar(35) as descr, 'Domestic Contiguous (Lower 48 U.S. States Only)'::varchar(255) as long_descr
order by 1;


-- 9. create and load air_oai_dims.airfare_classes
drop table if exists air_oai_dims.airfare_classes;
create table air_oai_dims.airfare_classes as
select '-'::char(1) as airfare_class_code, 'Ground'::varchar(35) as descr, 'Ground Segment'::varchar(255) as long_descr union all
select 'C'::char(1) as airfare_class_code, 'Biz Unl'::varchar(35) as descr, 'Unrestricted Business Class'::varchar(255) as long_descr union all
select 'D'::char(1) as airfare_class_code, 'Biz Lim'::varchar(35) as descr, 'Restricted Business Class'::varchar(255) as long_descr union all
select 'F'::char(1) as airfare_class_code, 'First Unl'::varchar(35) as descr, 'Unrestricted First Class'::varchar(255) as long_descr union all
select 'G'::char(1) as airfare_class_code, 'First Lim'::varchar(35) as descr, 'Restricted First Class'::varchar(255) as long_descr union all
select 'U'::char(1) as airfare_class_code, 'Unk'::varchar(35) as descr, 'Unknown'::varchar(255) as long_descr union all
select 'X'::char(1) as airfare_class_code, 'Econ Lim'::varchar(35) as descr, 'Restricted Coach Class'::varchar(255) as long_descr union all
select 'Y'::char(1) as airfare_class_code, 'Econ Unl'::varchar(35) as descr, 'Unrestricted Coach Class'::varchar(255) as long_descr
order by 1;


-- 10. create and load air_oai_dims.airline_traffic_data_sources
drop table if exists air_oai_dims.airline_traffic_data_sources;
create table air_oai_dims.airline_traffic_data_sources as
select 'DF'::varchar(5) as service_class_code, 'DOM, INTL carrier'::varchar(55) as descr, 'Domestic Data, Foreign Carriers'::varchar(255) as long_descr union all
select 'DU'::varchar(5) as service_class_code, 'DOM, US carrier'::varchar(55) as descr, 'Domestic Data, US Carriers Only'::varchar(255) as long_descr union all
select 'IF'::varchar(5) as service_class_code, 'INTL, INTL carrier'::varchar(55) as descr, 'International Data, Foreign Carriers'::varchar(255) as long_descr union all
select 'IU'::varchar(5) as service_class_code, 'INTL, US carrier'::varchar(55) as descr, 'International Data, US Carriers Only'::varchar(255) as long_descr
order by 1;


-- 11. add table constraints
-- aircraft_types 
alter table air_oai_dims.aircraft_types alter aircraft_type_oai_nbr set not null;
alter table air_oai_dims.aircraft_types alter aircraft_group_oai_nbr set not null;
alter table air_oai_dims.aircraft_types alter aircraft_oai_type set not null;
alter table air_oai_dims.aircraft_types alter manufacturer_name set not null;
alter table air_oai_dims.aircraft_types alter aircraft_type_long_name set not null;
alter table air_oai_dims.aircraft_types alter aircraft_type_brief_name set not null;
alter table air_oai_dims.aircraft_types alter aircraft_type_from_date set not null;
alter table air_oai_dims.aircraft_types alter created_by set not null;
alter table air_oai_dims.aircraft_types alter created_by set default current_user;
alter table air_oai_dims.aircraft_types alter created_tmst set not null;
alter table air_oai_dims.aircraft_types alter created_tmst set default current_timestamp;
alter table air_oai_dims.aircraft_types add constraint aircraft_types_pk primary key (aircraft_type_oai_nbr);

-- world_areas 
alter table air_oai_dims.world_areas alter world_area_oai_seq_id set not null;
alter table air_oai_dims.world_areas alter world_area_key set not null;
alter table air_oai_dims.world_areas alter world_area_oai_id set not null;
alter table air_oai_dims.world_areas alter effective_from_date set not null;
alter table air_oai_dims.world_areas alter created_by set not null;
alter table air_oai_dims.world_areas alter created_by set default current_user;
alter table air_oai_dims.world_areas alter created_tmst set not null;
alter table air_oai_dims.world_areas alter created_tmst set default current_timestamp;
alter table air_oai_dims.world_areas add constraint world_areas_pk primary key (world_area_oai_seq_id);
alter table air_oai_dims.world_areas add constraint world_areas_ak unique (world_area_key);
alter table air_oai_dims.world_areas add constraint world_areas_nk unique (world_area_oai_id, effective_from_date);

-- airline_entities 
alter table air_oai_dims.airline_entities alter airline_entity_id set not null;
alter table air_oai_dims.airline_entities alter airline_entity_key set not null;
alter table air_oai_dims.airline_entities alter airline_usdot_id set not null;
alter table air_oai_dims.airline_entities alter airline_oai_code set not null;
alter table air_oai_dims.airline_entities alter entity_oai_code set not null;
alter table air_oai_dims.airline_entities alter airline_name set not null;
alter table air_oai_dims.airline_entities alter airline_unique_oai_code set not null;
alter table air_oai_dims.airline_entities alter entity_unique_oai_code set not null;
alter table air_oai_dims.airline_entities alter airline_unique_name set not null;
alter table air_oai_dims.airline_entities alter world_area_oai_id set not null;
alter table air_oai_dims.airline_entities alter airline_old_group_nbr set not null;
alter table air_oai_dims.airline_entities alter airline_new_group_nbr set not null;
alter table air_oai_dims.airline_entities alter operating_region_code set not null;
alter table air_oai_dims.airline_entities alter source_from_date set not null;
alter table air_oai_dims.airline_entities alter created_by set not null;
alter table air_oai_dims.airline_entities alter created_by set default current_user;
alter table air_oai_dims.airline_entities alter created_tmst set not null;
alter table air_oai_dims.airline_entities alter created_tmst set default current_timestamp;
alter table air_oai_dims.airline_entities add constraint airline_entities_pk primary key (airline_entity_id);
alter table air_oai_dims.airline_entities add constraint airline_entities_ak unique (airline_entity_key);
alter table air_oai_dims.airline_entities add constraint airline_entities_nk unique (airline_oai_code, entity_oai_code, source_from_date);

-- airport_history 
alter table air_oai_dims.airport_history alter airport_history_id set not null;
alter table air_oai_dims.airport_history alter airport_history_key set not null;
alter table air_oai_dims.airport_history alter airport_oai_code set not null;
alter table air_oai_dims.airport_history alter effective_from_date set not null;
alter table air_oai_dims.airport_history alter airport_closed_ind set not null;
alter table air_oai_dims.airport_history alter airport_latest_ind set not null;
alter table air_oai_dims.airport_history alter airport_oai_seq_id set not null;
alter table air_oai_dims.airport_history alter airport_oai_id set not null;
alter table air_oai_dims.airport_history alter airport_display_name set not null;
alter table air_oai_dims.airport_history alter city_full_display_name set not null;
alter table air_oai_dims.airport_history alter airport_world_area_oai_seq_id set not null;
alter table air_oai_dims.airport_history alter airport_world_area_oai_id set not null;
alter table air_oai_dims.airport_history alter market_city_oai_seq_id set not null;
alter table air_oai_dims.airport_history alter market_city_oai_id set not null;
alter table air_oai_dims.airport_history alter market_city_full_display_name set not null;
alter table air_oai_dims.airport_history alter market_city_world_area_oai_seq_id set not null;
alter table air_oai_dims.airport_history alter market_city_world_area_oai_id set not null;
alter table air_oai_dims.airport_history alter country_name set not null;
alter table air_oai_dims.airport_history alter created_by set not null;
alter table air_oai_dims.airport_history alter created_by set default current_user;
alter table air_oai_dims.airport_history alter created_tmst set not null;
alter table air_oai_dims.airport_history alter created_tmst set default current_timestamp;
alter table air_oai_dims.airport_history add constraint airport_history_pk primary key (airport_history_id);
alter table air_oai_dims.airport_history add constraint airport_history_ak unique (airport_history_key);
alter table air_oai_dims.airport_history add constraint airport_history_nk unique (airport_oai_code, effective_from_date);

-- aircraft_type_groups 
alter table air_oai_dims.aircraft_type_groups alter aircraft_group_oai_nbr set not null;
alter table air_oai_dims.aircraft_type_groups alter descr set not null;
alter table air_oai_dims.aircraft_type_groups alter long_descr set not null;
alter table air_oai_dims.aircraft_type_groups alter created_by set not null;
alter table air_oai_dims.aircraft_type_groups alter created_ts set not null;
alter table air_oai_dims.aircraft_type_groups add constraint aircraft_type_groups_pk primary key (aircraft_group_oai_nbr);

-- airline_entity_new_groups 
alter table air_oai_dims.airline_entity_new_groups alter airline_new_group_nbr set not null;
alter table air_oai_dims.airline_entity_new_groups alter descr set not null;
alter table air_oai_dims.airline_entity_new_groups alter long_descr set not null;
alter table air_oai_dims.airline_entity_new_groups alter created_by set not null;
alter table air_oai_dims.airline_entity_new_groups alter created_ts set not null;
alter table air_oai_dims.airline_entity_new_groups add constraint airline_entity_new_groups_pk primary key (airline_new_group_nbr);

-- airline_entity_legacy_groups 
alter table air_oai_dims.airline_entity_legacy_groups alter airline_old_group_nbr set not null;
alter table air_oai_dims.airline_entity_legacy_groups alter descr set not null;
alter table air_oai_dims.airline_entity_legacy_groups alter long_descr set not null;
alter table air_oai_dims.airline_entity_legacy_groups alter created_by set not null;
alter table air_oai_dims.airline_entity_legacy_groups alter created_ts set not null;
alter table air_oai_dims.airline_entity_legacy_groups add constraint airline_entity_legacy_groups_pk primary key (airline_old_group_nbr);

-- airline_geographic_types 
alter table air_oai_dims.airline_geographic_types alter geograhic_type_oai_id set not null;
alter table air_oai_dims.airline_geographic_types alter descr set not null;
alter table air_oai_dims.airline_geographic_types alter long_descr set not null;
alter table air_oai_dims.airline_geographic_types add constraint airline_geographic_types_pk primary key (geograhic_type_oai_id);

-- airfare_classes 
alter table air_oai_dims.airfare_classes alter airfare_class_code set not null;
alter table air_oai_dims.airfare_classes alter descr set not null;
alter table air_oai_dims.airfare_classes alter long_descr set not null;
alter table air_oai_dims.airfare_classes add constraint airfare_classes_pk primary key (airfare_class_code);

-- airline_traffic_data_sources 
alter table air_oai_dims.airline_traffic_data_sources alter service_class_code set not null;
alter table air_oai_dims.airline_traffic_data_sources alter descr set not null;
alter table air_oai_dims.airline_traffic_data_sources alter long_descr set not null;
alter table air_oai_dims.airline_traffic_data_sources add constraint airline_traffic_data_sources_pk primary key (service_class_code);


-- 12. create presentation layer views
-- drop view if exists airlines_ddb.aircraft_types_v;
create or replace view airlines_ddb.aircraft_types_v as
SELECT aircraft_type_oai_nbr
	 , aircraft_group_oai_nbr
	 , aircraft_oai_type
	 , manufacturer_name
	 , aircraft_type_long_name
	 , aircraft_type_brief_name
	 , aircraft_type_from_date
	 , aircraft_type_thru_date
FROM air_oai_dims.aircraft_types;

-- drop view if exists airlines_ddb.airport_history_v;
create or replace view airlines_ddb.airport_history_v as
SELECT airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date
	, airport_closed_ind, airport_latest_ind, airport_oai_seq_id, airport_oai_id, airport_display_name
	, city_full_display_name
	, airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key
	, utc_local_time_variation, time_zone_name
	, market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name
	, market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_name
	, latitude_decimal_nbr, longitude_decimal_nbr
FROM air_oai_dims.airport_history;

-- drop view if exists airlines_ddb.airport_current_v;
create or replace view airlines_ddb.airport_current_v as
SELECT airport_oai_code
	, airport_closed_ind
	, airport_oai_id, airport_display_name
	, city_full_display_name
	, airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key
	, utc_local_time_variation, time_zone_name
	, market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name
	, market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_name
	, latitude_decimal_nbr, longitude_decimal_nbr
FROM air_oai_dims.airport_history
where airport_latest_ind = 1;

-- drop view if exists airlines_ddb.world_areas_v;
create or replace view airlines_ddb.world_areas_v as
SELECT world_area_oai_seq_id, world_area_key
	, world_area_oai_id, effective_from_date, effective_thru_date, world_area_latest_ind
	, world_area_name, world_region_name
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_short_name, country_type_descr
	, sovereign_country_name, capital_city_name, world_area_comments_text
FROM air_oai_dims.world_areas;

-- drop view if exists airlines_ddb.airline_entity_legacy_groups_v;
create or replace view airlines_ddb.airline_entity_legacy_groups_v as
select airline_old_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_legacy_groups;
	 
-- drop view if exists airlines_ddb.airline_entity_new_groups_v;
create or replace view airlines_ddb.airline_entity_new_groups_v as
select airline_new_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_new_groups;

-- drop view if exists airlines_ddb.airline_entities_v;
create or replace view airlines_ddb.airline_entities_v as
SELECT airline_entity_id
	, airline_entity_key
	, airline_usdot_id
	, airline_oai_code
	, entity_oai_code
	, airline_name
	, airline_unique_oai_code
	, entity_unique_oai_code
	, airline_unique_name
	, world_area_oai_id
	, world_area_oai_seq_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	, source_from_date
	, source_thru_date
FROM air_oai_dims.airline_entities;

-- drop view if exists airlines_ddb.airline_entities_current_v;
create or replace view airlines_ddb.airline_entities_current_v as
SELECT airline_oai_code
	, airline_usdot_id
	, entity_oai_code
	, airline_name
	, world_area_oai_id
	, world_area_oai_seq_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
FROM air_oai_dims.airline_entities
where source_thru_date is null;

-- drop view if exists airlines_ddb.airline_geographic_types_v;
create or replace view airlines_ddb.airline_geographic_types_v as
SELECT
	geograhic_type_oai_id
	, descr
	, long_descr
from air_oai_dims.airline_geographic_types;

-- drop view if exists airlines_ddb.airfare_classes_v;
create or replace view airlines_ddb.airfare_classes_v as
SELECT
	airfare_class_code
	, descr
	, long_descr
from air_oai_dims.airfare_classes;

-- drop view if exists airlines_ddb.airline_traffic_data_sources_v;
create or replace view airlines_ddb.airline_traffic_data_sources_v as
SELECT
	service_class_code
	, descr
	, long_descr
from air_oai_dims.airline_traffic_data_sources;
