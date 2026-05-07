-- Aviation Support/Dimension Tables (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Aviation Support Tables
-- https://transtats.bts.gov/Tables.asp?QO_VQ=IMI&QO_anzr=N8vn6v10%FDf722146%FDgnoyr5&QO_fu146_anzr=N8vn6v10%FDf722146%FDgnoyr5

-- STEPS:
-- 0. download and unzip individual pre-zipped data files: AircraftTypes, Carrier Decode, Master Coordinate, World Area Codes
-- 1. create aircraft types lookup 
--  1.1. create air_oai_dims.aircraft_types_fdw table in postgre
--  1.2. copy aircraft types data into air_oai_dims.aircraft_types_fdw
--  1.3. create air_oai_dims.aircraft_types table in postgre
--  1.4. copy data into air_oai_dims.aircraft_types from air_oai_dims.aircraft_types_fdw
-- 2. create world areas lookup 
--  2.1. create air_oai_dims.wac_country_state_fdw table in postgre
--  2.2. copy world areas data into air_oai_dims.wac_country_state_fdw
--  2.3. create air_oai_dims.world_areas table in postgre
--  2.4. copy data into air_oai_dims.world_areas from air_oai_dims.wac_country_state_fdw
-- 3. create airline entities lookup 
--  3.1. create air_oai_dims.carrier_decode_fdw table in postgre
--  3.2. copy aircraft types data into air_oai_dims.carrier_decode_fdw
--  3.3. create air_oai_dims.world_areas table in postgre
--  3.4. copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw
--  3.4.1 copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for non '3KQ' airline oai codes
--  3.4.2 copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for '3KQ' airline oai codes
-- 4. create airport history lookup 
--  4.1. create air_oai_dims.master_cord_fdw table in postgre  
--  4.2. copy world areas data into air_oai_dims.master_cord_fdw
--  4.3. create air_oai_dims.airport_history table in postgre
--  4.4. copy data into air_oai_dims.airport_history from air_oai_dims.master_cord_fdw
--  4.5 update world area keys in air_oai_dims.airport_history based on air_oai_dims.world_areas
--  4.6 update the time zone boundaries in air_oai_dims.airport_history 
-- 5. create aircraft types group lookup 
--  5.1. create air_oai_dims.aircraft_type_groups
--  5.2. load air_oai_dims.aircraft_type_groups from air_oai_dims.aircraft_types
-- 6. create airline entity group (new) lookup 
--  6.1. create air_oai_dims.airline_entity_new_groups
--  6.2. load air_oai_dims.airline_entity_new_groups from air_oai_dims.airline_entities
-- 7. create airport types group (legacy) lookup 
--  7.1. create air_oai_dims.airline_entity_legacy_groups
--  7.2. load air_oai_dims.airline_entity_legacy_groups from air_oai_dims.airline_entities
-- 8. create geographic types lookup (hardcoded)
-- 9. create airfare classes lookup (hardcoded)
-- 10. create traffic data sources lookup (hardcoded)
-- 11. define column comments
-- 12. create presentation layer view


----------------------------------------------------
-- 1. create aircraft types lookup 
----------------------------------------------------

drop table if exists air_oai_dims.aircraft_types_fdw;
create table air_oai_dims.aircraft_types_fdw
( 
    aircraft_type_oai_nbr          smallint    not null,
    aircraft_group_oai_nbr         smallint    not null,
    aircraft_oai_type              varchar(55) not null,
    manufacturer_name              varchar(55),
    aircraft_type_long_name        varchar(55) not null,
    aircraft_type_brief_name       varchar(55) not null,
    aircraft_type_from_date        date        not null,
    aircraft_type_thru_date        date
);

-- 1.2. copy aircraft types data into air_oai_dims.aircraft_types_fdw
COPY air_oai_dims.aircraft_types_fdw
FROM 's3://src-aviation/DIMS/CSV/T_AIRCRAFT_TYPES.csv'
FORMAT AS CSV
IGNOREHEADER 1
IAM_ROLE default
DATEFORMAT 'MM/DD/YYYY';

-- 1.3. create air_oai_dims.aircraft_types table in postgre
drop table if exists air_oai_dims.aircraft_types;
create table air_oai_dims.aircraft_types
( 
    aircraft_type_oai_nbr          smallint    not null,
    aircraft_group_oai_nbr         smallint    not null,
    aircraft_oai_type              varchar(55) not null,
    manufacturer_name              varchar(55) not null,
    aircraft_type_long_name        varchar(55) not null,
    aircraft_type_brief_name       varchar(55) not null,
    aircraft_type_from_date        date        not null,
    aircraft_type_thru_date        date,
    created_by                     varchar(32) not null default current_user,
    created_tmst                   timestamp   not null default current_timestamp,
    updated_by                     varchar(32),
    updated_tsmt                   timestamp,
    constraint aircraft_types_pk primary key (aircraft_type_oai_nbr)
);

-- 1.4. copy data into air_oai_dims.aircraft_types from air_oai_dims.aircraft_types_fdw
insert into air_oai_dims.aircraft_types
( 
    aircraft_type_oai_nbr,
    aircraft_group_oai_nbr,
    aircraft_oai_type,
    manufacturer_name,
    aircraft_type_long_name,
    aircraft_type_brief_name,
    aircraft_type_from_date,
    aircraft_type_thru_date,
    created_by,
    created_tmst
)
select f.aircraft_type_oai_nbr,
       f.aircraft_group_oai_nbr,
       f.aircraft_oai_type,
       case when f.manufacturer_name is null then 'GENERIC' else f.manufacturer_name end,
       f.aircraft_type_long_name,
       f.aircraft_type_brief_name,
       f.aircraft_type_from_date,
       f.aircraft_type_thru_date,
       current_user,
       current_timestamp
from air_oai_dims.aircraft_types_fdw f;

----------------------------------------------------
-- 2. create world areas lookup 
----------------------------------------------------

-- 2.1. create air_oai_dims.wac_country_state_fdw table in postgre
drop table if exists air_oai_dims.wac_country_state_fdw;
create table air_oai_dims.wac_country_state_fdw
( 
    world_area_oai_id              integer,
    world_area_oai_seq_id          integer,
    world_area_name                varchar(125),
    world_region_name              varchar(125),
    country_short_name             varchar(75),
    country_type_descr             varchar(75),
    capital_city_name              varchar(75),
    sovereign_country_name         varchar(75),
    country_iso_code               char(2),
    subdivision_iso_code           varchar(10),
    subdivision_name               varchar(75),
    subdivision_fips_code          varchar(10),
    effective_from_date            date,
    effective_thru_date            date,
    comments_text                  varchar(555),
    world_area_latest_ind          smallint
);

-- 2.2. copy world areas data into air_oai_dims.wac_country_state_fdw
copy air_oai_dims.wac_country_state_fdw
from 's3://src-aviation/DIMS/CSV/T_WAC_COUNTRY_STATE.csv'
iam_role default
csv
ignoreheader 1
dateformat 'auto'
timeformat 'auto'
acceptinvchars;

-- 2.3. create air_oai_dims.world_areas table in postgre
drop table if exists air_oai_dims.world_areas;
create table air_oai_dims.world_areas
( 
    world_area_oai_seq_id          integer      not null,
    world_area_key                 char(32)     not null,
    world_area_oai_id              smallint     not null,
    effective_from_date            date         not null,
    effective_thru_date            date,
    world_area_latest_ind          smallint,
    world_area_name                varchar(125),
    world_region_name              varchar(125),
    subdivision_iso_code           varchar(10),
    subdivision_fips_code          varchar(10),
    subdivision_name               varchar(75),
    country_iso_code               char(2),
    country_short_name             varchar(75),
    country_type_descr             varchar(75),
    sovereign_country_name         varchar(75),
    capital_city_name              varchar(75),
    world_area_comments_text       varchar(555),
    created_by                     varchar(32)  not null default current_user,
    created_tmst                   timestamp    not null default current_timestamp,
    updated_by                     varchar(32),
    updated_tsmt                   timestamp,
    constraint world_areas_pk primary key (world_area_oai_seq_id),
    constraint world_areas_ak unique (world_area_key),
    constraint world_areas_nk unique (world_area_oai_id, effective_from_date)
);

-- 2.4. copy data into air_oai_dims.world_areas from air_oai_dims.wac_country_state_fdw
insert into air_oai_dims.world_areas
( 
    world_area_oai_seq_id,
    world_area_key,
    world_area_oai_id,
    effective_from_date,
    effective_thru_date,
    world_area_latest_ind,
    world_area_name,
    world_region_name,
    subdivision_iso_code,
    subdivision_fips_code,
    subdivision_name,
    country_iso_code,
    country_short_name,
    country_type_descr,
    sovereign_country_name,
    capital_city_name,
    world_area_comments_text,
    created_by,
    created_tmst
)
select world_area_oai_seq_id,
       md5(world_area_oai_id::varchar ||'~'|| effective_from_date::varchar) as world_area_key,
       world_area_oai_id,
       effective_from_date,
       effective_thru_date,
       world_area_latest_ind,
       world_area_name,
       world_region_name,
       subdivision_iso_code,
       subdivision_fips_code,
       subdivision_name,
       country_iso_code,
       country_short_name,
       country_type_descr,
       sovereign_country_name,
       capital_city_name,
       comments_text,
       current_user,
       current_timestamp
from air_oai_dims.wac_country_state_fdw;

----------------------------------------------------
-- 3. create airline entities lookup 
----------------------------------------------------

-- 3.1. create air_oai_dims.carrier_decode_fdw table in postgre
drop table if exists air_oai_dims.carrier_decode_fdw;
create table air_oai_dims.carrier_decode_fdw
( 
    airline_usdot_id           smallint,
    airline_oai_code           varchar(10),
    entity_oai_code            varchar(10),
    airline_name               varchar(125),
    airline_unique_oai_code    varchar(10),
    entity_unique_oai_code     varchar(10),
    airline_unique_name        varchar(125),
    world_area_oai_id          smallint,
    airline_old_group_nbr      smallint,
    airline_new_group_nbr      smallint,
    operating_region_code      varchar(25),
    source_from_date           date,
    source_thru_date           date
);

-- 3.2. copy aircraft types data into air_oai_dims.carrier_decode_fdw
copy air_oai_dims.carrier_decode_fdw
from 's3://src-aviation/DIMS/CSV/T_CARRIER_DECODE.csv'
iam_role default
csv
ignoreheader 1
dateformat 'auto'
timeformat 'auto'
acceptinvchars;

-- 3.3. create air_oai_dims.world_areas table in postgre
drop table if exists air_oai_dims.airline_entities;
create table air_oai_dims.airline_entities
( 
    airline_entity_id          integer   not null identity(1,1),
    airline_entity_key         char(32)  not null,
    airline_usdot_id           smallint  not null,
    airline_oai_code           varchar(10) not null,
    entity_oai_code            varchar(10) not null,
    airline_name               varchar(125) not null,
    airline_unique_oai_code    varchar(10) not null,
    entity_unique_oai_code     varchar(10) not null,
    airline_unique_name        varchar(125) not null,
    world_area_oai_id          smallint not null,
    world_area_oai_seq_id      integer,
    airline_old_group_nbr      smallint not null,
    airline_new_group_nbr      smallint not null,
    operating_region_code      varchar(25) not null,
    source_from_date           date not null,
    source_thru_date           date,
    created_by                 varchar(32) not null default current_user,
    created_tmst               timestamp   not null default current_timestamp,
    updated_by                 varchar(32),
    updated_tsmt               timestamp,
    constraint airline_entities_pk primary key (airline_entity_id),
    constraint airline_entities_ak unique (airline_entity_key),
    constraint airline_entities_nk unique (airline_oai_code, entity_oai_code, source_from_date)
);

-- 3.4.1 copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for non '3KQ' airline oai codes
insert into air_oai_dims.airline_entities
( 
    airline_entity_key,
    airline_usdot_id,
    airline_oai_code,
    entity_oai_code,
    airline_name,
    airline_unique_oai_code,
    entity_unique_oai_code,
    airline_unique_name,
    world_area_oai_id,
    airline_old_group_nbr,
    airline_new_group_nbr,
    operating_region_code,
    source_from_date,
    source_thru_date,
    created_by,
    created_tmst
)
select md5(f.airline_oai_code||'~'||f.entity_oai_code||'~'||f.source_from_date::varchar),
       f.airline_usdot_id,
       f.airline_oai_code,
       f.entity_oai_code,
       f.airline_name,
       f.airline_unique_oai_code,
       f.entity_unique_oai_code,
       f.airline_unique_name,
       f.world_area_oai_id,
       f.airline_old_group_nbr,
       f.airline_new_group_nbr,
       f.operating_region_code,
       f.source_from_date,
       f.source_thru_date,
       current_user,
       current_timestamp
from air_oai_dims.carrier_decode_fdw f
where f.airline_oai_code <> '3KQ'
order by f.airline_usdot_id, f.airline_oai_code, f.entity_oai_code, f.source_from_date;

-- 3.4.2 copy data into air_oai_dims.world_areas from air_oai_dims.carrier_decode_fdw for '3KQ' airline oai codes
insert into air_oai_dims.airline_entities
( 
    airline_entity_key,
    airline_usdot_id,
    airline_oai_code,
    entity_oai_code,
    airline_name,
    airline_unique_oai_code,
    entity_unique_oai_code,
    airline_unique_name,
    world_area_oai_id,
    airline_old_group_nbr,
    airline_new_group_nbr,
    operating_region_code,
    source_from_date,
    source_thru_date,
    created_by,
    created_tmst
)
select md5(airline_oai_code||'~'||entity_oai_code||'~'||source_from_date::varchar),
       airline_usdot_id,
       airline_oai_code,
       entity_oai_code,
       airline_name,
       airline_unique_oai_code,
       entity_unique_oai_code,
       airline_unique_name,
       world_area_oai_id,
       airline_old_group_nbr,
       airline_new_group_nbr,
       operating_region_code,
       source_from_date,
       source_thru_date,
       current_user,
       current_timestamp
from (
    select max(f.airline_usdot_id) as airline_usdot_id,
           f.airline_oai_code,
           f.entity_oai_code,
           max(f.airline_name) as airline_name,
           max(f.airline_unique_oai_code) as airline_unique_oai_code,
           max(f.entity_unique_oai_code) as entity_unique_oai_code,
           max(f.airline_unique_name) as airline_unique_name,
           max(f.world_area_oai_id) as world_area_oai_id,
           max(f.airline_old_group_nbr) as airline_old_group_nbr,
           max(f.airline_new_group_nbr) as airline_new_group_nbr,
           max(f.operating_region_code) as operating_region_code,
           f.source_from_date,
           max(f.source_thru_date) as source_thru_date
    from air_oai_dims.carrier_decode_fdw f
    where f.airline_oai_code = '3KQ'
    group by airline_oai_code, entity_oai_code, source_from_date
) x;

----------------------------------------------------
-- 4. create airport history lookup 
----------------------------------------------------

-- 4.1. create air_oai_dims.master_cord_fdw table in postgre  
drop table if exists air_oai_dims.master_cord_fdw;
create table air_oai_dims.master_cord_fdw 
( 
    airport_oai_seq_id                     integer,
    airport_oai_id                         integer,
    airport_oai_code                       varchar(3),
    airport_display_name                   varchar(125),
    city_full_display_name                 varchar(125),
    airport_world_area_oai_seq_id          integer,
    airport_world_area_oai_id              integer,
    country_name                           varchar(75),
    country_iso_code                       varchar(10),
    subdivision_name                       varchar(75),
    subdivision_iso_code                   varchar(10),
    subdivision_fips_code                  varchar(10),
    market_city_oai_seq_id                 integer,
    market_city_oai_id                     integer,
    market_city_full_display_name          varchar(75),
    market_city_world_area_oai_seq_id      integer,
    market_city_world_area_oai_id          integer,
    latitude_degrees                       smallint,
    latitude_hemisphere_code               char(1),
    latitude_minutes                       smallint,
    latitude_seconds                       smallint,
    latitude_decimal_nbr                   numeric(9,7),
    longitude_degrees                      smallint,
    longitude_hemisphere_code              char(1),
    longitude_minutes                      smallint,
    longitude_seconds                      smallint,
    longitude_decimal_nbr                  numeric(10,7),
    utc_local_time_variation               varchar(75),
    airport_effective_from_date            date,
    airport_effective_thru_date            date,
    airport_closed_ind                     smallint,
    airport_latest_ind                     smallint
);

-- 4.2. copy world areas data into air_oai_dims.master_cord_fdw
copy air_oai_dims.master_cord_fdw
from 's3://src-aviation/DIMS/CSV/T_MASTER_CORD.csv'
iam_role default
csv
ignoreheader 1
dateformat 'auto'
timeformat 'auto'
acceptinvchars;

-- 4.3. create air_oai_dims.airport_history table in postgre
drop table if exists air_oai_dims.airport_history;
create table air_oai_dims.airport_history 
( 
    airport_history_id                  integer    not null identity(1,1),
    airport_history_key                 char(32)   not null,
    airport_oai_code                    varchar(3) not null,
    effective_from_date                 date       not null,
    effective_thru_date                 date,
    airport_closed_ind                  smallint   not null,
    airport_latest_ind                  smallint   not null,
    airport_oai_seq_id                  integer    not null,
    airport_oai_id                      integer    not null,
    airport_display_name                varchar(125) not null,
    city_full_display_name              varchar(125) not null,
    airport_world_area_oai_seq_id       integer    not null,
    airport_world_area_oai_id           integer    not null,
    airport_world_area_key              char(32),
    utc_local_time_variation            char(5),
    time_zone_name                      varchar(100),
    market_city_oai_seq_id              integer    not null,
    market_city_oai_id                  integer    not null,
    market_city_full_display_name       varchar(75) not null,
    market_city_world_area_oai_seq_id   integer    not null,
    market_city_world_area_oai_id       integer    not null,
    market_city_world_area_key          char(32),
    subdivision_iso_code                varchar(10),
    subdivision_fips_code               varchar(10),
    subdivision_name                    varchar(75),
    country_iso_code                    varchar(10),
    country_name                        varchar(75) not null,
    latitude_decimal_nbr                numeric(9,7),
    longitude_decimal_nbr               numeric(10,7),
    -- point_geom                        geometry  -- Not available in Redshift
    created_by                          varchar(32)  not null default current_user,
    created_tmst                        timestamp    not null default current_timestamp,
    updated_by                          varchar(32),
    updated_tsmt                        timestamp,
    constraint airport_history_pk primary key (airport_history_id),
    constraint airport_history_ak unique (airport_history_key),
    constraint airport_history_nk unique (airport_oai_code, effective_from_date)
);

-- 4.4. copy data into air_oai_dims.airport_history from air_oai_dims.master_cord_fdw
insert into air_oai_dims.airport_history
( 
    airport_history_key,
    airport_oai_code,
    effective_from_date,
    effective_thru_date,
    airport_closed_ind,
    airport_latest_ind,
    airport_oai_seq_id,
    airport_oai_id,
    airport_display_name,
    city_full_display_name,
    airport_world_area_oai_seq_id,
    airport_world_area_oai_id,
    utc_local_time_variation,
    market_city_oai_seq_id,
    market_city_oai_id,
    market_city_full_display_name,
    market_city_world_area_oai_seq_id,
    market_city_world_area_oai_id,
    subdivision_iso_code,
    subdivision_fips_code,
    subdivision_name,
    country_iso_code,
    country_name,
    latitude_decimal_nbr,
    longitude_decimal_nbr,
    created_by,
    created_tmst
)
select md5(upper(m.airport_oai_code)||'~'||m.airport_effective_from_date::varchar),
       m.airport_oai_code,
       m.airport_effective_from_date,
       m.airport_effective_thru_date,
       m.airport_closed_ind,
       m.airport_latest_ind,
       m.airport_oai_seq_id,
       m.airport_oai_id,
       m.airport_display_name,
       m.city_full_display_name,
       m.airport_world_area_oai_seq_id,
       m.airport_world_area_oai_id,
       case when len(coalesce(m.utc_local_time_variation,'')) = 0
            then null
            else SUBSTRING(m.utc_local_time_variation,1,5)
       end,
       m.market_city_oai_seq_id,
       m.market_city_oai_id,
       m.market_city_full_display_name,
       m.market_city_world_area_oai_seq_id,
       m.market_city_world_area_oai_id,
       m.subdivision_iso_code,
       m.subdivision_fips_code,
       m.subdivision_name,
       m.country_iso_code,
       m.country_name,
       m.latitude_decimal_nbr,
       m.longitude_decimal_nbr,
       current_user,
       current_timestamp
from air_oai_dims.master_cord_fdw m;

-- 4.5 update world area keys in air_oai_dims.airport_history based on air_oai_dims.world_areas
update air_oai_dims.airport_history ah
set airport_world_area_key      = abc.airport_world_area_key,
    market_city_world_area_key  = abc.market_city_world_area_key
from (
    select a.airport_history_id,
           a.airport_history_key,
           b.world_area_key as airport_world_area_key,
           c.world_area_key as market_city_world_area_key
    from air_oai_dims.airport_history a
    left join air_oai_dims.world_areas b
      on a.airport_world_area_oai_id = b.world_area_oai_id
     and a.airport_world_area_oai_seq_id = b.world_area_oai_seq_id
    left join air_oai_dims.world_areas c
      on a.market_city_world_area_oai_id = c.world_area_oai_id
     and a.market_city_world_area_oai_seq_id = c.world_area_oai_seq_id
) abc
where ah.airport_history_id = abc.airport_history_id
  and ah.airport_history_key = abc.airport_history_key;

-- 4.6 update the time zone boundaries in air_oai_dims.airport_history

UPDATE air_oai_dims.airport_history
SET 
    time_zone_name = sub.time_zone_name,
    updated_by = CURRENT_USER,
    updated_tsmt = SYSDATE
FROM (
    -- Subquery to perform the spatial join
    SELECT 
        a.airport_history_id, 
        b.tzid AS time_zone_name
    FROM air_oai_dims.airport_history a
    JOIN public.timezone_boundaries b 
      ON ST_Intersects(b.geom, a.point_geom)
    WHERE a.time_zone_name IS NULL
) AS sub
WHERE air_oai_dims.airport_history.airport_history_id = sub.airport_history_id
  AND air_oai_dims.airport_history.time_zone_name IS NULL;

----------------------------------------------------
-- 5. create aircraft types group lookup 
----------------------------------------------------

-- 5.1. create air_oai_dims.aircraft_type_groups
drop table if exists air_oai_dims.aircraft_type_groups;
create table air_oai_dims.aircraft_type_groups
(
  aircraft_group_oai_nbr smallint not null,
  descr                  varchar(55) not null,
  long_descr             varchar(255) not null,
  created_by             varchar(32) not null,
  created_ts             timestamp   not null
);

-- 5.2. load air_oai_dims.aircraft_type_groups from air_oai_dims.aircraft_types
insert into air_oai_dims.aircraft_type_groups
(
    aircraft_group_oai_nbr,
    descr,
    long_descr,
    created_by,
    created_ts
)
select distinct coalesce(aircraft_group_oai_nbr, -1) as aircraft_group_oai_nbr,
       case aircraft_group_oai_nbr
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
       end as descr,
       case aircraft_group_oai_nbr
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
       end as long_descr,
       current_user   as created_by,
       current_timestamp as created_ts
from air_oai_dims.aircraft_types;

----------------------------------------------------
-- 6. create airline entity group (new) lookup 
----------------------------------------------------

-- 6.1. create air_oai_dims.airline_entity_new_groups
drop table if exists air_oai_dims.airline_entity_new_groups;
create table air_oai_dims.airline_entity_new_groups
(
  airline_new_group_nbr smallint not null,
  descr                 varchar(55) not null,
  long_descr            varchar(255) not null,
  created_by            varchar(32) not null,
  created_ts            timestamp not null
);

-- 6.2. load air_oai_dims.airline_entity_new_groups from air_oai_dims.airline_entities
insert into air_oai_dims.airline_entity_new_groups
(
  airline_new_group_nbr,
  descr,
  long_descr,
  created_by,
  created_ts
)
select distinct coalesce(airline_new_group_nbr, -1) as airline_new_group_nbr,
       case airline_new_group_nbr
            when 0 then 'Foreign'
            when 1 then 'Large Regional'
            when 2 then 'National'
            when 3 then 'Major'
            when 4 then 'Medium'
            when 5 then 'Small, Certified'
            when 6 then 'Commuter, Large'
            when 7 then 'All Cargo'
            when 9 then 'Commuter, Essential'
            else 'UNK'
       end as descr,
       case airline_new_group_nbr
            when 0 then 'Foreign Carriers'
            when 1 then 'Large Regional Carriers (carriers with annual revenue of $20 million to $100 million))'
            when 2 then 'National Carriers (carriers with annual revenue over 100 milion to 1 billion)'
            when 3 then 'Major Carriers (carriers with annual revenue over $1 billion'
            when 4 then 'Medium Regional Carriers (carriers with annual revenue under $20 million)'
            when 5 then 'Small Certificated Carriers (carrier holding certificate issued under 49 U.S.C. section 41101 and operating aircraft designed to have a maximum seating capacity of 60 or less seat or a maximum payload of 18,000 pounds or less.)'
            when 6 then 'Commuter Carriers (air taxi operator which performs at least five round trips per week between two or more points and publishes flight schedules which specify the times, days of the weeks and plans between which such flights are performed.'
            when 7 then 'All Cargo Carriers operating under cerificates issued under 49 U.S.C. section 41103'
            when 9 then 'Commuter Carriers (Air Taxi providing Essential Air Service)'
            else 'UNK'
       end as long_descr,
       current_user    as created_by,
       current_timestamp as created_ts
from air_oai_dims.airline_entities;

----------------------------------------------------
-- 7. create airport types group (legacy) lookup 
----------------------------------------------------

-- 7.1. create air_oai_dims.airline_entity_legacy_groups
drop table if exists air_oai_dims.airline_entity_legacy_groups;
create table air_oai_dims.airline_entity_legacy_groups
(
  airline_old_group_nbr smallint not null,
  descr                 varchar(55) not null,
  long_descr            varchar(255) not null,
  created_by            varchar(32) not null,
  created_ts            timestamp not null
);

-- 7.2. load air_oai_dims.airline_entity_legacy_groups from air_oai_dims.airline_entities
insert into air_oai_dims.airline_entity_legacy_groups
(
  airline_old_group_nbr,
  descr,
  long_descr,
  created_by,
  created_ts
)
select distinct coalesce(airline_old_group_nbr, -1) as airline_old_group_nbr,
       case airline_old_group_nbr
            when 0 then 'International'
            when 1 then 'Regional'
            when 2 then 'National'
            when 3 then 'Major'
            when 7 then 'All Cargo'
            else 'UNK'
       end as descr,
       case airline_old_group_nbr
            when 0 then 'International Carriers'
            when 1 then 'Regional Carriers (including Large, Medium, Commuter, Small Certified)'
            when 2 then 'National Carriers'
            when 3 then 'Major Carriers'
            when 7 then 'Domestic Only - All Cargo Carriers'
            else 'UN'
       end as long_descr,
       current_user    as created_by,
       current_timestamp as created_ts
from air_oai_dims.airline_entities;

----------------------------------------------------
-- 8. create air_oai_dims.airline_geographic_types


drop table if exists air_oai_dims.airline_geographic_types;
create table air_oai_dims.airline_geographic_types
as
select 0::smallint as geograhic_type_oai_id,
       'International'::varchar(35) as descr,
       'International travel between indepedent soverign states.'::varchar(255) as long_descr
union
select 1::smallint, 'Domestic, Global'::varchar(35),
       'Domestic Non-contiguous (Includes Hawaii, Alaska and Territories)'::varchar(255)
union
select 2::smallint, 'Domestic, Lower48'::varchar(35),
       'Domestic Contiguous (Lower 48 U.S. States Only)'::varchar(255)
order by 1;

-- 9. create air_oai_dims.airfare_classes

drop table if exists air_oai_dims.airfare_classes;
create table air_oai_dims.airfare_classes
as
select '-'::char(1) as airfare_class_code,
       'Ground'::varchar(35) as descr,
       'Ground Segment'::varchar(255) as long_descr
union
select 'C'::char(1), 'Biz Unl'::varchar(35), 'Unrestricted Business Class'::varchar(255)
union
select 'D'::char(1), 'Biz Lim'::varchar(35), 'Restricted Business Class'::varchar(255)
union
select 'F'::char(1), 'First Unl'::varchar(35), 'Unrestricted First Class'::varchar(255)
union
select 'G'::char(1), 'First Lim'::varchar(35), 'Restricted First Class'::varchar(255)
union
select 'U'::char(1), 'Unk'::varchar(35), 'Unknown'::varchar(255)
union
select 'X'::char(1), 'Econ Lim'::varchar(35), 'Restricted Coach Class'::varchar(255)
union
select 'Y'::char(1), 'Econ Unl'::varchar(35), 'Unrestricted Coach Class'::varchar(255)
order by 1;


-- 10. create air_oai_dims.airline_traffic_data_sources

drop table if exists air_oai_dims.airline_traffic_data_sources;
create table air_oai_dims.airline_traffic_data_sources
as
select 'DF'::varchar(5) as service_class_code,
       'DOM, INTL carrier'::varchar(55) as descr,
       'Domestic Data, Foreign Carriers'::varchar(255) as long_descr
union
select 'DU'::varchar(5), 'DOM, US carrier'::varchar(55),
       'Domestic Data, US Carriers Only'::varchar(255)
union
select 'IF'::varchar(5), 'INTL, INTL carrier'::varchar(55),
       'International Data, Foreign Carriers'::varchar(255)
union
select 'IU'::varchar(5), 'INTL, US carrier'::varchar(55),
       'International Data, US Carriers Only'::varchar(255)
order by 1;

-- 11. define column comments

--  Comments for aircraft_types
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_type_oai_nbr IS 'AC_TYPEID = Aircraft Type Identification Number. This Number Is Related To The Aircraft Group Number And Falls Within The Range Of A Group Number.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_group_oai_nbr IS 'AC_GROUP = Aircraft Type Group - This Number Gives The Group Or Classification Of Aircraft Engine And Type Of Aircraft.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_oai_type IS 'SSD_NAME = Aircraft Name.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.manufacturer_name IS 'MANUFACTURER = Manufacturing Company Name.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_type_long_name IS 'LONG_NAME = Complete Name Of The Aircraft.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_type_brief_name IS 'SHORT_NAME = Abbreviated Name Of The Aircraft.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_type_from_date IS 'BEGIN_DATE = The Date When The Aircraft Was Added To The Database.';
COMMENT ON COLUMN air_oai_dims.aircraft_types.aircraft_type_thru_date IS 'END_DATE = The Date Through Which Aircraft Type Remains In Effect.';

-- Comments for world_areas
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_key IS 'MD5-hashed unique key of [world_area_oai_id & ~ & effective_from_date]';
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_oai_id IS 'WAC = World Area Code.';
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_oai_seq_id IS 'WAC_SEQ_ID2 = Unique Identifier for a World Area Code (WAC) at a given point of time. WAC attributes may change over time. For example the country name associated with the WAC can change, but the WAC code stays the same.';
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_name IS 'WAC_NAME = World Area Code Name.';
COMMENT ON COLUMN air_oai_dims.world_areas.world_region_name IS 'WORLD_AREA_NAME = Geographic Region of World Area Code.';
COMMENT ON COLUMN air_oai_dims.world_areas.country_short_name IS 'COUNTRY_SHORT_NAME = Country Name.';
COMMENT ON COLUMN air_oai_dims.world_areas.country_type_descr IS 'COUNTRY_TYPE = Country Type.';
COMMENT ON COLUMN air_oai_dims.world_areas.capital_city_name IS 'CAPITAL = Capital.';
COMMENT ON COLUMN air_oai_dims.world_areas.sovereign_country_name IS 'SOVEREIGNTY = Sovereignty.';
COMMENT ON COLUMN air_oai_dims.world_areas.country_iso_code IS 'COUNTRY_CODE_ISO = Two-Character ISO Country Code.';
COMMENT ON COLUMN air_oai_dims.world_areas.subdivision_iso_code IS 'STATE_CODE = State Abbreviation.';
COMMENT ON COLUMN air_oai_dims.world_areas.subdivision_name IS 'STATE_NAME = State Name.';
COMMENT ON COLUMN air_oai_dims.world_areas.subdivision_fips_code IS 'STATE_FIPS = FIPS (Federal Information Processing Standard) State Code.';
COMMENT ON COLUMN air_oai_dims.world_areas.effective_from_date IS 'START_DATE = Start Date of World Area Code Attributes.';
COMMENT ON COLUMN air_oai_dims.world_areas.effective_thru_date IS 'THRU_DATE = End Date of World Area Code Attributes (Active = NULL).';
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_comments_text IS 'COMMENTS = Comments.';
COMMENT ON COLUMN air_oai_dims.world_areas.world_area_latest_ind IS 'IS_LATEST = Indicates if this row contains the latest attributes for the World Area Code (1 = Yes).';

-- Comments for airline_entities
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_entity_id IS 'PostgreSQL defined identity surrogate key for high performance joins. Start with 4000.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_entity_key IS 'md5 hash of natural key <carrier_oai_code|entity_oai_code|source_from_date>.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_usdot_id IS 'AIRLINE_ID = An identification number assigned by US DOT to identify a unique airline (carrier). A unique airline (carrier) is defined as one holding and reporting under the same DOT certificate regardless of its Code, Name, or holding company/corporation.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_oai_code IS 'CARRIER = Code assigned by IATA and commonly used to identify a carrier. As the same code may have been assigned to different carriers over time, the code is not always unique.';
COMMENT ON COLUMN air_oai_dims.airline_entities.entity_oai_code IS 'CARRIER_ENTITY = Carrier Entity.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_name IS 'CARRIER_NAME = Carrier Name.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_unique_oai_code IS 'UNIQUE_CARRIER = Unique Carrier Code. When the same code has been used by multiple carriers, a numeric suffix is used for earlier users, for example, PA, PA(1), PA(2). Use this field for analysis across a range of years.';
COMMENT ON COLUMN air_oai_dims.airline_entities.entity_unique_oai_code IS 'UNIQUE_CARRIER_ENTITY = Unique Entity for a Carrier Operation Region.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_unique_name IS 'UNIQUE_CARRIER_NAME = Unique Carrier Name. When the same name has been used by multiple carriers, a numeric suffix is used for earlier users, for example, Air Caribbean, Air Caribbean (1).';
COMMENT ON COLUMN air_oai_dims.airline_entities.world_area_oai_id IS 'WAC = World Area Code, this is a non-unique ID that represents a WAC.';
COMMENT ON COLUMN air_oai_dims.airline_entities.world_area_oai_seq_id IS 'WAC = World Area Code, this is actual FK, since it is unique over time.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_old_group_nbr IS 'CARRIER_GROUP = Carrier Group Code. Used in Legacy Analysis.';
COMMENT ON COLUMN air_oai_dims.airline_entities.airline_new_group_nbr IS 'CARRIER_GROUP_NEW = Carrier Group New.';
COMMENT ON COLUMN air_oai_dims.airline_entities.operating_region_code IS 'REGION = Carrier Operation Region. Carriers Report Data by Operation Region.';
COMMENT ON COLUMN air_oai_dims.airline_entities.source_from_date IS 'START_DATE_SOURCE = Starting Date of Carrier Code.';
COMMENT ON COLUMN air_oai_dims.airline_entities.source_thru_date IS 'THRU_DATE_SOURCE = Ending Date of Carrier Code (Active = NULL).';

-- Comments for airport_history
COMMENT ON COLUMN air_oai_dims.airport_history.airport_oai_seq_id IS 'AIRPORT_SEQ_ID = An identification number assigned by US DOT to identify a unique airport at a given point of time. Airport attributes, such as airport name or coordinates, may change over time.';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_oai_id IS 'AIRPORT_ID = An identification number assigned by US DOT to identify a unique airport. Use this field for airport analysis across a range of years because an airport can change its airport code and airport codes can be reused.';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_oai_code IS 'AIRPORT = A three character alpha-numeric code issued by the U.S. Department of Transportation which is the official designation of the airport. The airport code is not always unique to a specific airport because airport codes can change or can be reused.';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_display_name IS 'DISPLAY_AIRPORT_NAME = Airport Name.';
COMMENT ON COLUMN air_oai_dims.airport_history.city_full_display_name IS 'DISPLAY_AIRPORT_CITY_NAME_FULL = Airport City Name with either U.S. State or Country.';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_world_area_oai_id IS 'AIRPORT_WAC = World Area Code for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.country_name IS 'AIRPORT_COUNTRY_NAME = Country Name for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.country_iso_code IS 'AIRPORT_COUNTRY_CODE_ISO = Two-character ISO Country Code for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.subdivision_name IS 'AIRPORT_STATE_NAME = State Name for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.subdivision_iso_code IS 'AIRPORT_STATE_CODE = State Abbreviation for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.subdivision_fips_code IS 'AIRPORT_STATE_FIPS = FIPS (Federal Information Processing Standard) State Code for the Physical Location of the Airport.';
COMMENT ON COLUMN air_oai_dims.airport_history.market_city_oai_id IS 'CITY_MARKET_ID = An identification number assigned by US DOT to identify a city market. Use this field to consolidate airports serving the same city market.';
COMMENT ON COLUMN air_oai_dims.airport_history.market_city_full_display_name IS 'DISPLAY_CITY_MARKET_NAME_FULL = City Market Name with either U.S. State or Country';
COMMENT ON COLUMN air_oai_dims.airport_history.market_city_world_area_oai_id IS 'CITY_MARKET_WAC = World Area Code for the City Market';
COMMENT ON COLUMN air_oai_dims.airport_history.latitude_decimal_nbr IS 'LATITUDE = Latitude';
COMMENT ON COLUMN air_oai_dims.airport_history.longitude_decimal_nbr IS 'LONGITUDE = Longitude';
COMMENT ON COLUMN air_oai_dims.airport_history.effective_from_date IS 'AIRPORT_START_DATE = Start Date of Airport Attributes';
COMMENT ON COLUMN air_oai_dims.airport_history.effective_thru_date IS 'AIRPORT_THRU_DATE = End Date of Airport Attributes (Active = NULL)';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_closed_ind IS 'AIRPORT_IS_CLOSED = Indicates if the airport is closed (1 = Yes). If yes, the airport is closed is on the AirportEndDate.';
COMMENT ON COLUMN air_oai_dims.airport_history.airport_latest_ind IS 'AIRPORT_IS_LATEST = Indicates if this row contains the latest attributes for the Airport (1 = Yes)';

----------------------------------------------------
-- 12. create presentation layer view
----------------------------------------------------

CREATE SCHEMA IF NOT EXISTS airlines_pg;

create or replace view airlines_pg.aircraft_types_v as
select aircraft_type_oai_nbr,
       aircraft_group_oai_nbr,
       aircraft_oai_type,
       manufacturer_name,
       aircraft_type_long_name,
       aircraft_type_brief_name,
       aircraft_type_from_date,
       aircraft_type_thru_date
from air_oai_dims.aircraft_types;

create or replace view airlines_pg.airport_history_v as
select airport_history_id, airport_history_key, airport_oai_code, effective_from_date, effective_thru_date,
       airport_closed_ind, airport_latest_ind, airport_oai_seq_id, airport_oai_id, airport_display_name,
       city_full_display_name,
       airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key,
       utc_local_time_variation, time_zone_name,
       market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name,
       market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key,
       subdivision_iso_code, subdivision_fips_code, subdivision_name,
       country_iso_code, country_name,
       latitude_decimal_nbr, longitude_decimal_nbr
from air_oai_dims.airport_history;

create or replace view airlines_pg.airport_current_v as
select airport_oai_code,
       airport_closed_ind,
       airport_oai_id, airport_display_name,
       city_full_display_name,
       airport_world_area_oai_seq_id, airport_world_area_oai_id, airport_world_area_key,
       utc_local_time_variation, time_zone_name,
       market_city_oai_seq_id, market_city_oai_id, market_city_full_display_name,
       market_city_world_area_oai_seq_id, market_city_world_area_oai_id, market_city_world_area_key,
       subdivision_iso_code, subdivision_fips_code, subdivision_name,
       country_iso_code, country_name,
       latitude_decimal_nbr, longitude_decimal_nbr
from air_oai_dims.airport_history
where airport_latest_ind = 1;

create or replace view airlines_pg.world_areas_v as
select world_area_oai_seq_id, world_area_key,
       world_area_oai_id, effective_from_date, effective_thru_date, world_area_latest_ind,
       world_area_name, world_region_name,
       subdivision_iso_code, subdivision_fips_code, subdivision_name,
       country_iso_code, country_short_name, country_type_descr,
       sovereign_country_name, capital_city_name, world_area_comments_text
from air_oai_dims.world_areas;

create or replace view airlines_pg.airline_entity_legacy_groups_v as
select airline_old_group_nbr,
       descr,
       long_descr
from air_oai_dims.airline_entity_legacy_groups;

create or replace view airlines_pg.airline_entity_new_groups_v as
select airline_new_group_nbr,
       descr,
       long_descr
from air_oai_dims.airline_entity_new_groups;

create or replace view airlines_pg.airline_entities_v as
select airline_entity_id,
       airline_entity_key,
       airline_usdot_id,
       airline_oai_code,
       entity_oai_code,
       airline_name,
       airline_unique_oai_code,
       entity_unique_oai_code,
       airline_unique_name,
       world_area_oai_id,
       world_area_oai_seq_id,
       airline_old_group_nbr,
       airline_new_group_nbr,
       operating_region_code,
       source_from_date,
       source_thru_date
from air_oai_dims.airline_entities;

create or replace view airlines_pg.airline_entities_current_v as
select airline_oai_code,
       airline_usdot_id,
       entity_oai_code,
       airline_name,
       world_area_oai_id,
       world_area_oai_seq_id,
       airline_old_group_nbr,
       airline_new_group_nbr,
       operating_region_code
from air_oai_dims.airline_entities
where source_thru_date is null;

create or replace view airlines_pg.airline_geographic_types_v as
select geograhic_type_oai_id,
       descr,
       long_descr
from air_oai_dims.airline_geographic_types;

create or replace view airlines_pg.airfare_classes_v as
select airfare_class_code,
       descr,
       long_descr
from air_oai_dims.airfare_classes;

create or replace view airlines_pg.airline_traffic_data_sources_v as
select service_class_code,
       descr,
       long_descr
from air_oai_dims.airline_traffic_data_sources;