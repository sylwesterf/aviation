-- Air Carrier Financial Reports (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Financial Reports (Form 41 Financial Data)
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EGI&QO_anzr=Nv4%FDPn44vr4%FDSv0n0pvny%FDer21465%FD%FLS14z%FDHE%FDSv0n0pvny%FDQn6n%FM&QO_fu146_anzr=Nv4%FDPn44vr4%FDSv0n0pvny

----------------------------------------------------
-- STEPS:
-- 0. download and unzip pre-zipped data file: Annual Inventory of Airframe and Aircraft Engines
-- 1. create air_oai_dims.f41_schedule_b43_fdw table in postgre
-- 2. copy Annual Inventory of Airframe and Aircraft Engines data into air_oai_dims.f41_schedule_b43_fdw
-- 3. create and load air_oai_dims.airframe_and_engine_inventory_annual from air_oai_dims.f41_schedule_b43_fdw
-- 4. define keys and indexes
-- 5. add comments 
-- 6. create presentation layer views
----------------------------------------------------

-- 1. create air_oai_dims.f41_schedule_b43_fdw table in postgre
----------------------------------------------------
-- 1. TABLA STAGING f41_schedule_b43_fdw EN REDSHIFT
----------------------------------------------------

drop table if exists air_oai_dims.f41_schedule_b43_fdw;

create table air_oai_dims.f41_schedule_b43_fdw
( 
    year_nbr                smallint,
    carrier_oai_code        varchar(3),
    carrier_name            varchar(125),
    manufacture_year_nbr    smallint,
    carrier_unique_name     varchar(125),
    serial_nbr              varchar(25),
    tail_nbr                varchar(25),
    aircraft_status_code    varchar(25),
    operating_status_code   varchar(25),
    seats_qty               integer,
    manufacturer_name       varchar(75),
    aircraft_oai_type       varchar(15),
    model_ref               varchar(25),
    capacity_lbr            integer,
    acquisition_date        date,
    airline_id              smallint,
    carrier_unique_oai_code varchar(7)
    -- filler_txt            varchar(10)
);

----------------------------------------------------
-- 2. COPY DESDE S3 A f41_schedule_b43_fdw
----------------------------------------------------

copy air_oai_dims.f41_schedule_b43_fdw
from 's3://src-aviation/FIN/CSV/T_F41SCHEDULE_B43.csv.gz'
iam_role default
csv
ignoreheader 1
gzip
dateformat 'auto'
timeformat 'auto'
acceptinvchars;

----------------------------------------------------
-- 3. FINAL TABLE airframe_and_engine_inventory_annual
----------------------------------------------------

drop table if exists air_oai_dims.airframe_and_engine_inventory_annual;

create table air_oai_dims.airframe_and_engine_inventory_annual
distkey(airline_entity_id)  -- opcional, puedes ajustar distkey/sortkey
sortkey(airline_entity_id, year_nbr, tail_nbr, serial_nbr)
as
select 
    md5(
        year_nbr::varchar
        ||'~'|| replace(f.carrier_oai_code,' ','')
        ||'~'|| tail_nbr
        ||'~'|| serial_nbr
    )::char(32)                               as inventory_key,
    ae.airline_entity_id                      as airline_entity_id,
    max(ae.airline_entity_key)::char(32)      as airline_entity_key,
    max(replace(f.carrier_oai_code,' ',''))::varchar(3) as airline_oai_code,
    f.year_nbr                                as year_nbr,
    f.tail_nbr::varchar(10)                   as tail_nbr,
    f.serial_nbr::varchar(10)                 as serial_nbr,
    max(upper(f.manufacturer_name))::varchar(75) as manufacturer_name,
    max(f.model_ref)::varchar(15)             as model_ref,
    max(replace(f.aircraft_oai_type,' ',''))::varchar(10) as aircraft_oai_type,
    null::char(4)                             as aircraft_icao_type,
    null::varchar(3)                          as aircraft_iata_type,
    min(f.manufacture_year_nbr)::smallint     as manufacture_year_nbr,
    min(f.acquisition_date)::date             as acquisition_date,
    max(f.aircraft_status_code)::char(1)      as aircraft_status_code,
    max(f.operating_status_code)::char(1)     as operating_status_ind,
    max(f.seats_qty)                          as seats_qty,
    max(f.capacity_lbr)                       as capacity_lbr,
    current_user::varchar(32)                 as created_by,
    current_timestamp                         as created_ts,
    null::varchar(25)                         as updated_by,
    null::timestamp                           as updated_ts
from air_oai_dims.f41_schedule_b43_fdw f
left join (
    select *
    from air_oai_dims.airline_entities
    where operating_region_code = 'Domestic'
) ae 
  on replace(f.carrier_oai_code,' ','') = replace(ae.airline_oai_code,' ','')
where (f.year_nbr::varchar || '-01-01')::date
      between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
group by ae.airline_entity_id,
         f.year_nbr,
         f.tail_nbr,
         f.serial_nbr,
         replace(f.carrier_oai_code,' ','')
order by ae.airline_entity_id, f.year_nbr, f.tail_nbr, f.serial_nbr;

----------------------------------------------------
-- 4. KEYS / INDEX (Redshift: PK/UNIQUE )
----------------------------------------------------

alter table air_oai_dims.airframe_and_engine_inventory_annual
    add constraint airframe_and_engine_inventory_annual_pk
    primary key (inventory_key);

create unique index airframe_and_engine_inventory_annual_nk
on air_oai_dims.airframe_and_engine_inventory_annual
(airline_entity_id, year_nbr, tail_nbr, serial_nbr);

----------------------------------------------------
-- 6. VIEWS
----------------------------------------------------

create or replace view airlines_pg.airframe_and_engine_inventory_annual_v as
select inventory_key,
       airline_entity_id,
       airline_entity_key,
       airline_oai_code,
       year_nbr,
       tail_nbr,
       serial_nbr,
       manufacturer_name,
       model_ref,
       aircraft_oai_type,
       aircraft_icao_type,
       aircraft_iata_type,
       manufacture_year_nbr,
       acquisition_date,
       aircraft_status_code,
       operating_status_ind,
       seats_qty,
       capacity_lbr
from air_oai_dims.airframe_and_engine_inventory_annual;

create or replace view airlines_pg.airline_aircraft_by_tail_v as 
select airline_entity_id,
       max(airline_entity_key)       as airline_entity_key,
       max(airline_oai_code)         as airline_oai_code,
       min(year_nbr)                 as min_year_nbr,
       max(year_nbr)                 as max_year_nbr,
       tail_nbr,
       max(serial_nbr)               as serial_nbr,
       max(manufacturer_name)        as manufacturer_name,
       max(model_ref)                as model_ref,
       max(aircraft_oai_type)        as aircraft_oai_type,
       max(aircraft_icao_type)       as aircraft_icao_type,
       max(aircraft_iata_type)       as aircraft_iata_type,
       max(manufacture_year_nbr)     as manufacture_year_nbr,
       max(acquisition_date)         as acquisition_date,
       max(aircraft_status_code)     as aircraft_status_code,
       max(operating_status_ind)     as operating_status_ind,
       max(seats_qty)                as seats_qty,
       max(capacity_lbr)             as capacity_lbr
from air_oai_dims.airframe_and_engine_inventory_annual
group by airline_entity_id, tail_nbr;