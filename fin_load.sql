-- Air Carrier Financial Reports (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Air Carrier Financial Reports (Form 41 Financial Data)
-- https://www.transtats.bts.gov/Tables.asp?QO_VQ=EGI&QO_anzr=Nv4%FDPn44vr4%FDSv0n0pvny%FDer21465%FD%FLS14z%FDHE%FDSv0n0pvny%FDQn6n%FM&QO_fu146_anzr=Nv4%FDPn44vr4%FDSv0n0pvny

----------------------------------------------------
-- STEPS:
-- 0. download and unzip pre-zipped data file: Annual Inventory of Airframe and Aircraft Engines
-- 1. create air_oai_dims.airframe_and_engine_inventory_annual by streaming a scv file from S3
-- 2. define keys and indexes
-- 3. create presentation layer views
----------------------------------------------------

-- 1. load air_oai_dims.airframe_and_engine_inventory_annual from Form 41 Schedule B-43
drop table if exists air_oai_dims.airframe_and_engine_inventory_annual;
create table air_oai_dims.airframe_and_engine_inventory_annual 
as
select 
	md5(year_nbr::text ||'~'|| replace(f.carrier_oai_code,' ','') ||'~'|| tail_nbr ||'~'|| serial_nbr)::char(32) as inventory_key -- add seats_qty, capacity_lbr
     , ae.airline_entity_id
     , max(ae.airline_entity_key)::char(32) as airline_entity_key
     , max(replace(f.carrier_oai_code,' ',''))::varchar(3) as airline_oai_code
     , f.year_nbr 
	 , f.tail_nbr::varchar(10)
	 , f.serial_nbr::varchar(10) 
	 , max(upper(f.manufacturer_name))::varchar(75)  as manufacturer_name
	 , max(f.model_ref)::varchar(15) as model_ref
	 , max(replace(f.aircraft_oai_type,' ',''))::varchar(10) as aircraft_oai_type
	 , null::char(4) as aircraft_icao_type
	 , null::varchar(3) as aircraft_iata_type
	 --, max(at.aircraft_type_brief_name) as aircraft_type_brief_name
	 , min(f.manufacture_year_nbr)::smallint as manufacture_year_nbr
	 , min(f.acquisition_date)::date as acquisition_date
	 , max(f.aircraft_status_code)::char(1) as aircraft_status_code
	 , max(f.operating_status_code)::char(1) as operating_status_ind
	 , max(f.seats_qty) as seats_qty
	 , max(f.capacity_lbr) as capacity_lbr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::varchar(25) as updated_by
     , null::timestamp(0) as updated_ts
from read_csv('s3://src-aviation/FIN/CSV/T_F41SCHEDULE_B43.csv.gz') f
left join (
    select * 
    from air_oai_dims.airline_entities 
    where operating_region_code = 'Domestic'
) ae on replace(f.carrier_oai_code, ' ', '') = replace(ae.airline_oai_code, ' ', '')
where (f.year_nbr::varchar || '-01-01')::date between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
group by 
      ae.airline_entity_id
    , f.year_nbr
    , f.tail_nbr
    , f.serial_nbr
    , replace(f.carrier_oai_code, ' ', '')
order by 
      ae.airline_entity_id
    , f.year_nbr
    , f.tail_nbr
    , f.serial_nbr;

-- 2. define keys and indexes
alter table air_oai_dims.airframe_and_engine_inventory_annual add primary key (inventory_key);

-- 3. create presentation layer views
-- drop view if exists airlines_pg.airframe_and_engine_inventory_annual_v;
create or replace view airlines_pg.airframe_and_engine_inventory_annual_v as
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

-- drop view if exists airlines_pg.airline_aircraft_by_tail_v;
CREATE OR REPLACE VIEW airlines_pg.airline_aircraft_by_tail_v AS 
SELECT airline_entity_id,
    max(airline_entity_key) AS airline_entity_key,
    max(airline_oai_code::text) AS airline_oai_code,
    min(year_nbr) AS min_year_nbr,
    max(year_nbr) AS max_year_nbr,
    tail_nbr,
    max(serial_nbr::text) AS serial_nbr,
    max(manufacturer_name::text) AS manufacturer_name,
    max(model_ref::text) AS model_ref,
    max(aircraft_oai_type::text) AS aircraft_oai_type,
    max(aircraft_icao_type) AS aircraft_icao_type,
    max(aircraft_iata_type::text) AS aircraft_iata_type,
    max(manufacture_year_nbr) AS manufacture_year_nbr,
    max(acquisition_date) AS acquisition_date,
    max(aircraft_status_code) AS aircraft_status_code,
    max(operating_status_ind) AS operating_status_ind,
    max(seats_qty) AS seats_qty,
    max(capacity_lbr) AS capacity_lbr
FROM air_oai_dims.airframe_and_engine_inventory_annual
GROUP BY airline_entity_id, tail_nbr;