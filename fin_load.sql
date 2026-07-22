-- Air Carrier Financial Reports (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Financial Reports (Form 41 Financial Data)
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EGI&QO_anzr=Nv4%FDPn44vr4%FDSv0n0pvny%FDer21465%FD%FLS14z%FDHE%FDSv0n0pvny%FDQn6n%FM&QO_fu146_anzr=Nv4%FDPn44vr4%FDSv0n0pvny

----------------------------------------------------
-- STEPS:
-- 0. download and unzip pre-zipped data file: Annual Inventory of Airframe and Aircraft Engines
-- 1. create and load air_oai_dims.airframe_and_engine_inventory_annual
-- 2. add table constraints
-- 3. create presentation layer views
----------------------------------------------------

-- 1. create and load air_oai_dims.airframe_and_engine_inventory_annual
drop table if exists air_oai_dims.airframe_and_engine_inventory_annual;
create table air_oai_dims.airframe_and_engine_inventory_annual as
with raw_f41 as (
    select 
          c1::integer as year_nbr
        , replace(nullif(trim(c2), ''), ' ', '')::varchar(10) as carrier_oai_code
        , nullif(trim(c7), '')::varchar(10) as tail_nbr
        , nullif(trim(c6), '')::varchar(10) as serial_nbr
        , nullif(trim(c11), '')::varchar(75) as manufacturer_name
        , nullif(trim(c13), '')::varchar(15) as model_ref
        , replace(nullif(trim(c12), ''), ' ', '')::varchar(10) as aircraft_oai_type
        , c4::smallint as manufacture_year_nbr
        , c15::date as acquisition_date
        , nullif(trim(c8), '')::char(1) as aircraft_status_code
        , nullif(trim(c9), '')::char(1) as operating_status_code
        , c10::smallint as seats_qty
        , c14::integer as capacity_lbr
    from read_csv(
          's3://src-aviation/FIN/CSV/T_F41SCHEDULE_B43.csv.gz'
        , header=true
        , dateformat='%m/%d/%Y %I:%M:%S %p'
        , columns={
              'c1': 'VARCHAR'  -- YEAR
            , 'c2': 'VARCHAR'  -- CARRIER
            , 'c3': 'VARCHAR'  -- CARRIER_NAME
            , 'c4': 'VARCHAR'  -- MANUFACTURE_YEAR
            , 'c5': 'VARCHAR'  -- UNIQUE_CARRIER_NAME
            , 'c6': 'VARCHAR'  -- SERIAL_NUMBER
            , 'c7': 'VARCHAR'  -- TAIL_NUMBER
            , 'c8': 'VARCHAR'  -- AIRCRAFT_STATUS
            , 'c9': 'VARCHAR'  -- OPERATING_STATUS
            , 'c10': 'VARCHAR' -- NUMBER_OF_SEATS
            , 'c11': 'VARCHAR' -- MANUFACTURER
            , 'c12': 'VARCHAR' -- AIRCRAFT_TYPE
            , 'c13': 'VARCHAR' -- MODEL
            , 'c14': 'VARCHAR' -- CAPACITY_IN_POUNDS
            , 'c15': 'DATE'    -- ACQUISITION_DATE
            , 'c16': 'VARCHAR' -- AIRLINE_ID
            , 'c17': 'VARCHAR' -- UNIQUE_CARRIER
          }
    )
),
filtered_entities as (
    select 
          replace(airline_oai_code, ' ', '') as airline_oai_code
        , airline_entity_id
        , airline_entity_key
        , source_from_date
        , source_thru_date
    from air_oai_dims.airline_entities 
    where operating_region_code = 'Domestic'
)
select 
      md5(f.year_nbr::varchar ||'~'|| f.carrier_oai_code ||'~'|| f.tail_nbr ||'~'|| f.serial_nbr)::char(32) as inventory_key
    , ae.airline_entity_id
    , max(ae.airline_entity_key)::char(32) as airline_entity_key
    , max(f.carrier_oai_code)::varchar(3) as airline_oai_code
    , f.year_nbr 
    , f.tail_nbr
    , f.serial_nbr 
    , max(upper(f.manufacturer_name))::varchar(75) as manufacturer_name
    , max(f.model_ref)::varchar(15) as model_ref
    , max(f.aircraft_oai_type)::varchar(10) as aircraft_oai_type
    , null::char(4) as aircraft_icao_type
    , null::varchar(3) as aircraft_iata_type
    , min(f.manufacture_year_nbr)::smallint as manufacture_year_nbr
    , min(f.acquisition_date)::date as acquisition_date
    , max(f.aircraft_status_code)::char(1) as aircraft_status_code
    , max(f.operating_status_code)::char(1) as operating_status_ind
    , max(f.seats_qty)::smallint as seats_qty
    , max(f.capacity_lbr)::integer as capacity_lbr
    , current_user::varchar(32) as created_by
    , current_timestamp::timestamp as created_ts
    , null::varchar(25) as updated_by
    , null::timestamp as updated_ts
from raw_f41 f
left join filtered_entities ae 
  on f.carrier_oai_code = ae.airline_oai_code
where make_date(f.year_nbr, 1, 1) between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
group by 
      ae.airline_entity_id
    , f.year_nbr
    , f.tail_nbr
    , f.serial_nbr
    , f.carrier_oai_code
order by 
      ae.airline_entity_id
    , f.year_nbr
    , f.tail_nbr
    , f.serial_nbr;

-- 2. add table constraints
alter table air_oai_dims.airframe_and_engine_inventory_annual alter inventory_key set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter airline_entity_id set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter airline_entity_key set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter airline_oai_code set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter year_nbr set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter tail_nbr set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter serial_nbr set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter created_by set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual alter created_ts set not null;
alter table air_oai_dims.airframe_and_engine_inventory_annual add constraint airframe_and_engine_inventory_annual_pk primary key (inventory_key);

-- 3. create presentation layer views
-- drop view if exists airlines_ddb.airframe_and_engine_inventory_annual_v;
create or replace view airlines_ddb.airframe_and_engine_inventory_annual_v as
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
	, manufacture_year_nbr
	, acquisition_date
	, aircraft_status_code
	, operating_status_ind
	, seats_qty
	, capacity_lbr
from air_oai_dims.airframe_and_engine_inventory_annual;

-- drop view if exists airlines_ddb.airline_aircraft_by_tail_v;
create or replace view airlines_ddb.airline_aircraft_by_tail_v as 
select airline_entity_id,
    max(airline_entity_key) as airline_entity_key,
    max(airline_oai_code) as airline_oai_code,
    min(year_nbr) as min_year_nbr,
    max(year_nbr) as max_year_nbr,
    tail_nbr,
    max(serial_nbr) as serial_nbr,
    max(manufacturer_name) as manufacturer_name,
    max(model_ref) as model_ref,
    max(aircraft_oai_type) as aircraft_oai_type,
    max(aircraft_icao_type) as aircraft_icao_type,
    max(aircraft_iata_type) as aircraft_iata_type,
    max(manufacture_year_nbr) as manufacture_year_nbr,
    max(acquisition_date) as acquisition_date,
    max(aircraft_status_code) as aircraft_status_code,
    max(operating_status_ind) as operating_status_ind,
    max(seats_qty) as seats_qty,
    max(capacity_lbr) as capacity_lbr
from air_oai_dims.airframe_and_engine_inventory_annual
group by airline_entity_id, tail_nbr;