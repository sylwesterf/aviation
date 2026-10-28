-- Air Carrier Financial Reports (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Financial Reports (Form 41 Financial Data)
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EGI&QO_anzr=Nv4%FDPn44vr4%FDSv0n0pvny%FDer21465%FD%FLS14z%FDHE%FDSv0n0pvny%FDQn6n%FM&QO_fu146_anzr=Nv4%FDPn44vr4%FDSv0n0pvny

----------------------------------------------------
-- 0. download and unzip pre-zipped data file: Annual Inventory of Airframe and Aircraft Engines
-- 1. create air_oai_dims.f41_schedule_b43_fdw table in postgre
-- 2. copy Annual Inventory of Airframe and Aircraft Engines data into air_oai_dims.f41_schedule_b43_fdw
-- 3. create and load air_oai_dims.airframe_and_engine_inventory_annual from air_oai_dims.f41_schedule_b43_fdw
-- 4. define keys and indexes
-- 5. add comments 
-- 6. create presentation layer views
----------------------------------------------------

-- 1.  create air_oai_dims.f41_schedule_b43_fdw table
drop table if exists air_oai_dims.f41_schedule_b43_fdw;
create table air_oai_dims.f41_schedule_b43_fdw
( 
    year_nbr                smallint,        -- Reporting year
    carrier_oai_code        varchar(3),      -- Carrier OAI code
    carrier_name            varchar(125),    -- Carrier name
    manufacture_year_nbr    smallint,        -- Aircraft manufacture year
    carrier_unique_name     varchar(125),    -- Carrier unique name
    serial_nbr              varchar(25),     -- Aircraft serial number
    tail_nbr                varchar(25),     -- Aircraft tail number
    aircraft_status_code    varchar(25),     -- Aircraft status code (raw)
    operating_status_code   varchar(25),     -- Operating status code (raw)
    seats_qty               integer,         -- Number of seats
    manufacturer_name       varchar(300),    -- Aircraft manufacturer
    aircraft_oai_type       varchar(15),     -- OAI aircraft type
    model_ref               varchar(25),     -- Model reference
    capacity_lbr            integer,         -- Capacity in pounds
    acquisition_date        date,            -- Acquisition date
    airline_id              smallint,        -- Airline identifier (source)
    carrier_unique_oai_code varchar(7)       -- Carrier unique OAI code
    -- filler_txt            varchar(10)     -- Optional filler field (unused)
);


-- 2. copy Annual Inventory of Airframe and Aircraft Engines data into air_oai_dims.f41_schedule_b43_fdw
copy air_oai_dims.f41_schedule_b43_fdw
from 's3://src-aviation/FIN/CSV/T_F41SCHEDULE_B43.csv.gz'
iam_role default
csv 
gzip
ignoreheader 1
dateformat 'auto';

-- 3.  create and load air_oai_dims.airframe_and_engine_inventory_annual from air_oai_dims.f41_schedule_b43_fdw
drop table if exists air_oai_dims.airframe_and_engine_inventory_annual;
create table air_oai_dims.airframe_and_engine_inventory_annual (
    inventory_key          char(32) not null, -- MD5 business key
    airline_entity_id      integer,          -- Airline entity surrogate ID
    airline_entity_key     char(32),         -- Airline entity business key
    airline_oai_code       varchar(3),       -- Airline OAI code (normalized)
    year_nbr               smallint,         -- Reporting year
    tail_nbr               varchar(10),      -- Tail number (normalized)
    serial_nbr             varchar(10),      -- Serial number (normalized)
    manufacturer_name      varchar(75),      -- Standardized manufacturer name
    model_ref              varchar(15),      -- Standardized model reference
    aircraft_oai_type      varchar(10),      -- Normalized OAI aircraft type
    aircraft_icao_type     char(4),          -- ICAO aircraft type code (future use)
    aircraft_iata_type     varchar(3),       -- IATA aircraft type code (future use)
    manufacture_year_nbr   smallint,         -- Manufacture year
    acquisition_date       date,             -- Acquisition date
    aircraft_status_code   char(1),          -- Aggregated aircraft status
    operating_status_ind   char(1),          -- Aggregated operating status
    seats_qty              integer,          -- Maximum seats across records
    capacity_lbr           integer,          -- Maximum capacity (lbs)
    created_by             varchar(32),      -- Audit: record creator
    created_ts             timestamp,        -- Audit: creation timestamp
    updated_by             varchar(25),      -- Audit: last updater
    updated_ts             timestamp         -- Audit: last update timestamp
);


-- 3. create and load air_oai_dims.airframe_and_engine_inventory_annual from air_oai_dims.f41_schedule_b43_fdw
insert into air_oai_dims.airframe_and_engine_inventory_annual
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
    -- Filter airline_entities to domestic operations only
    select *
    from air_oai_dims.airline_entities
    where operating_region_code = 'Domestic'
) ae 
  on replace(f.carrier_oai_code,' ','') = replace(ae.airline_oai_code,' ','')
-- Apply temporal validity filter using source_from_date / source_thru_date
where (f.year_nbr::varchar || '-01-01')::date
      between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
group by ae.airline_entity_id,
         f.year_nbr,
         f.tail_nbr,
         f.serial_nbr,
         replace(f.carrier_oai_code,' ','')
order by ae.airline_entity_id, f.year_nbr, f.tail_nbr, f.serial_nbr;


-- 4. define keys and indexes
alter table air_oai_dims.airframe_and_engine_inventory_annual
    add constraint airframe_and_engine_inventory_annual_nk
    unique (airline_entity_id, year_nbr, tail_nbr, serial_nbr);

-- 5. add comments 
comment on table air_oai_dims.airframe_and_engine_inventory_annual is 'Annual Inventory of Airframe and Aircraft Engines.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.inventory_key is 'composite hashed key of year_nbr~airline_oai_code~tail_nbr~serial_nbr.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.airline_entity_id is 'Foreign key column to air_oai_dims.airline_entities.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.airline_entity_key is 'Alternate Foreign key column to air_oai_dims.airline_entities.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.airline_oai_code is 'Code assigned by IATA and commonly used to identify a carrier. As the same code may have been assigned to different carriers over time, the code is not always unique. For analysis, use the Unique Carrier Code.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.year_nbr is 'Year that this inventory record applies, or was conducted.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.tail_nbr is 'Tail Number, this should be the registered number with the FAA, and painted on the aircraft.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.serial_nbr is 'Serial Number, this should be the sequential number aspplied by the manufacturer to this airframe.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.manufacturer_name  is 'Company that initially produced this airframe.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.model_ref is 'Model reference, a short code that identifies the model (or class) for this airframe.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.aircraft_oai_type is 'This should be a FK reference to air_oai_dims.aircraft_types, but seems incomplete.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.aircraft_icao_type is 'The standard code published by ICAO for this aircraft model.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.aircraft_iata_type is 'The standard code published by IATA for this aircraft model.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.manufacture_year_nbr is 'the year that this airframe was produced.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.acquisition_date is 'Date that this airframe was acquired or placed in service by this airline.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.aircraft_status_code is 'Aircraft Status - unknown codes.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.operating_status_ind is 'Operating Status, Y for operation, N for non-operational.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.seats_qty is 'Number Of Seats available for passengers.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.capacity_lbr is 'Available Capacity in Pounds, presumably payload.';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.created_by is 'audit column, who loaded this row?';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.created_ts  is 'audit column, when was this row loaded?';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.updated_by is 'audit column, who modified this row?';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.updated_ts  is 'audit column, when was this row modified?';

-- 6. create presentation layer views
--  drop view if exists airlines_rs.airframe_and_engine_inventory_annual_v;
create or replace view airlines_rs.airframe_and_engine_inventory_annual_v as
select inventory_key
	, airline_entity_id
	, airline_entity_key
	, airline_oai_code
	, year_nbr 
	, tail_nbr
	, serial_nbr 
	, manufacturer_name
	, model_ref
	, aircraft_oai_type
	, aircraft_icao_type
	, aircraft_iata_type
	--, aircraft_type_brief_name
	, manufacture_year_nbr
	, acquisition_date
	, aircraft_status_code
	, operating_status_ind
	, seats_qty
	, capacity_lbr
from air_oai_dims.airframe_and_engine_inventory_annual;

-- drop view if exists airlines_rs.airline_aircraft_by_tail_v;
create or replace view airlines_rs.airline_aircraft_by_tail_v as 
select airline_entity_id,
       max(airline_entity_key)       as airline_entity_key,   -- Latest airline entity key
       max(airline_oai_code)         as airline_oai_code,     -- Airline OAI code
       min(year_nbr)                 as min_year_nbr,         -- First year recorded
       max(year_nbr)                 as max_year_nbr,         -- Last year recorded
       tail_nbr,                                             -- Tail number
       max(serial_nbr)               as serial_nbr,           -- Serial number
       max(manufacturer_name)        as manufacturer_name,    -- Manufacturer
       max(model_ref)                as model_ref,            -- Model
       max(aircraft_oai_type)        as aircraft_oai_type,    -- OAI type
       max(aircraft_icao_type)       as aircraft_icao_type,   -- ICAO type
       max(aircraft_iata_type)       as aircraft_iata_type,   -- IATA type
       max(manufacture_year_nbr)     as manufacture_year_nbr, -- Manufacture year
       max(acquisition_date)         as acquisition_date,     -- Acquisition date
       max(aircraft_status_code)     as aircraft_status_code, -- Status
       max(operating_status_ind)     as operating_status_ind, -- Operating status
       max(seats_qty)                as seats_qty,            -- Max seats
       max(capacity_lbr)             as capacity_lbr          -- Max capacity
from air_oai_dims.airframe_and_engine_inventory_annual
group by airline_entity_id, tail_nbr;
