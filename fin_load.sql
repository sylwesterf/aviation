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
DROP TABLE IF EXISTS air_oai_dims.f41_schedule_b43_fdw;
CREATE TABLE air_oai_dims.f41_schedule_b43_fdw
( 
	year_nbr 							smallint
	, carrier_oai_code 					varchar(3)
	, carrier_name 						varchar(125)
	, manufacture_year_nbr 				smallint
	, carrier_unique_name 				varchar(125)
	, serial_nbr 						varchar(25)
	, tail_nbr 							varchar(25)
	, aircraft_status_code 				varchar(25)
	, operating_status_code 			varchar(25)
	, seats_qty 						integer
	, manufacturer_name 				varchar(75)
	, aircraft_oai_type					varchar(15)
	, model_ref 						varchar(25)
	, capacity_lbr 						integer
	, acquisition_date 					date
	, airline_id 						smallint
	, carrier_unique_oai_code 			varchar(7)
	--, filler_txt 						varchar(10)
);

-- 2. copy Annual Inventory of Airframe and Aircraft Engines data into air_oai_dims.f41_schedule_b43_fdw (Aurora S3)
SELECT aws_s3.table_import_from_s3('air_oai_dims.f41_schedule_b43_fdw','', '(FORMAT CSV, HEADER true)',aws_commons.create_s3_uri('src-aviation', '/FIN/CSV/T_F41SCHEDULE_B43.csv.gz', 'us-west-2'));

-- 3. create and load air_oai_dims.airframe_and_engine_inventory_annual from air_oai_dims.f41_schedule_b43_fdw
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
from air_oai_dims.f41_schedule_b43_fdw f
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') ae 
  on replace(f.carrier_oai_code,' ','') = replace(ae.airline_oai_code,' ','')
--left join air_oai_dims.aircraft_types at on f.aircraft_oai_type = at.aircraft_type_oai_nbr::text
where (f.year_nbr::text ||'-01-01')::date between source_from_date and coalesce(source_thru_date, current_date)
--and at.aircraft_type_oai_nbr is not null
group by ae.airline_entity_id, f.year_nbr, f.tail_nbr, f.serial_nbr, replace(f.carrier_oai_code,' ','')
order by ae.airline_entity_id, f.year_nbr, f.tail_nbr, f.serial_nbr;

-- 4. define keys and indexes
alter table air_oai_dims.airframe_and_engine_inventory_annual add constraint airframe_and_engine_inventory_annual_pk primary key (inventory_key);
create unique index airframe_and_engine_inventory_annual_nk on air_oai_dims.airframe_and_engine_inventory_annual (airline_entity_id, year_nbr, tail_nbr, serial_nbr);

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
comment on column air_oai_dims.airframe_and_engine_inventory_annual.created_ts is 'audit column, when was this row loaded?';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.updated_by is 'audit column, who modified this row?';
comment on column air_oai_dims.airframe_and_engine_inventory_annual.updated_ts is 'audit column, when was this row modified?';

-- 6. create presentation layer views
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