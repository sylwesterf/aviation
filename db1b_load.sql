-- DB1B (US DoT data)
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BTicket
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BCoupon
-- Bureau of Transportation Statistics (TranStats) > Aviation Data Library > Airline Origin and Destination Survey (DB1B) > DB1BMarket
-- https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFI&Yv0x=D

----------------------------------------------------
--STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/
-- 1. process DB1B Ticket data
--  1.1. create table air_oai_facts.airfare_survey_ticket_load to stage the data
--  1.2. ingest ticket csv data
--  1.3. create fact table air_oai_facts.airfare_survey_itinerary
--  1.4. insert data into fact table
-- 2. process DB1B Coupon data
--  2.1. create table air_oai_facts.airfare_survey_coupon_load to stage the data
--  2.2. ingest coupon csv data
--  2.3. create air_oai_facts.airfare_survey_coupon
--  2.4. insert data into fact table
-- 3. process DB1B Market data
--  3.1. create table air_oai_facts.airfare_survey_market_load to stage the data
--  3.2. ingest market csv data
--  3.3. create table airfare_survey_market
--  3.4. insert data into fact table
-- 4. create presentation layer views
----------------------------------------------------

-- 1. process DB1B Ticket data
-- 1.1. create table air_oai_facts.airfare_survey_ticket_load to stage the data
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_ticket_load;
CREATE TABLE air_oai_facts.airfare_survey_ticket_load
(
	  itinerary_oai_id								bigint
	, coupon_qty									real
	, year_nbr										integer
	, quarter_nbr									integer
	, depart_airport_oai_code						char(3)
	, depart_airport_oai_id							integer
	, depart_airport_oai_seq_id						integer
	, depart_market_city_oai_id						integer
	, depart_country_iso_code						char(2)
	, depart_subdivision_fips_code					char(2)
	, depart_subdivision_iso_code         			varchar(3)
	, depart_subdivision_name						varchar(75)
	, depart_wac_oai_id								integer
	, round_trip_ind            					real
	, online_ind									real
	, fare_credibility_ind							real
	, fare_per_smi									real
	, reporting_airline_oai_code					varchar(3)
	, passenger_qty           						real
	, fare_per_person_amount_usd					real
	, bulk_fare_ind									real
	, distance_smi									real
	, distance_group_oai_id							integer
	, flown_distance_smi							real
	, geographic_type_oai_id						integer
);
 
-- 1.2. ingest ticket csv data (Redshift COPY from S3)
-- single file:
--COPY air_oai_facts.airfare_survey_ticket_load
--FROM 's3://src-aviation/DB1B/ticket/CSV/Origin_and_Destination_Survey_DB1BTicket_2025_1.csv.gz'
--IAM_ROLE default
--CSV GZIP
--DELIMITER ','
--IGNOREHEADER 1 
--REGION 'us-west-2'
--FILLRECORD;

-- multiple files 
COPY air_oai_facts.airfare_survey_ticket_load
FROM 's3://src-aviation/DB1B/ticket/CSV/'
IAM_ROLE default
CSV GZIP
DELIMITER ','
IGNOREHEADER 1
REGION 'us-west-2';
 
-- 1.3. create fact table air_oai_facts.airfare_survey_itinerary 
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_itinerary;
CREATE TABLE air_oai_facts.airfare_survey_itinerary
(
	  itinerary_oai_id								bigint    not null
	, year_quarter_start_date						date      not null
	, year_quarter_nbr								integer   not null
	, reporting_airline_entity_id					integer  not null
	, reporting_airline_entity_key					char(32)  not null
	, depart_airport_history_id						integer   not null
	, depart_airport_history_key					char(32)  not null
	, round_trip_fare_ind            				integer
	, online_purchase_ind							integer
	, bulk_fare_ind									integer
	, fare_credibility_ind							integer
	, distance_group_oai_id							integer
	, geographic_type_oai_id						integer
	, coupon_qty									integer
	, passenger_qty           						integer
	, distance_smi									integer
	, flown_distance_smi							integer
	, fare_per_person_usd							integer
	, fare_per_mile_usd								numeric(10,5)
	, created_by 									varchar(32)  not null
	, created_tmst 									timestamp    not null
	, updated_by 									varchar(32)
	, updated_tsmt 									timestamp
	, constraint airfare_survey_itinerary_pk primary key (itinerary_oai_id, year_quarter_start_date)
)
 
-- 1.4. insert data into fact table
INSERT INTO air_oai_facts.airfare_survey_itinerary
(
	  itinerary_oai_id
	, year_quarter_start_date
	, year_quarter_nbr
	, reporting_airline_entity_id
	, reporting_airline_entity_key
	, depart_airport_history_id
	, depart_airport_history_key
	, round_trip_fare_ind
	, online_purchase_ind
	, bulk_fare_ind
	, fare_credibility_ind
	, distance_group_oai_id
	, geographic_type_oai_id
	, coupon_qty
	, passenger_qty
	, distance_smi
	, flown_distance_smi
	, fare_per_person_usd
	, fare_per_mile_usd
	, created_by
	, created_tmst
)
WITH filtered_airline_entities AS (
    SELECT airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    FROM air_oai_dims.airline_entities
    WHERE operating_region_code = 'Domestic'
)
SELECT asf.itinerary_oai_id
	, ac.year_quarter_from_date      as year_quarter_start_date
	, ac.year_quarter_nbr
    , ae.airline_entity_id           as reporting_airline_entity_id
    , ae.airline_entity_key          as reporting_airline_entity_key
    , ah.airport_history_id          as depart_airport_history_id
    , ah.airport_history_key         as depart_airport_history_key
    , asf.round_trip_ind
	, asf.online_ind
	, asf.bulk_fare_ind
	, asf.fare_credibility_ind
    , asf.distance_group_oai_id
	, asf.geographic_type_oai_id
	, asf.coupon_qty
	, asf.passenger_qty
	, asf.distance_smi
	, asf.flown_distance_smi
	, asf.fare_per_person_amount_usd
	, asf.fare_per_smi
	, current_user::varchar(32)
	, current_timestamp::timestamp
FROM air_oai_facts.airfare_survey_ticket_load asf
join calendar_rs.gregorian_year_quarter ac
  ON asf.year_nbr = ac.year_nbr AND asf.quarter_nbr = ac.quarter_of_year_nbr
left join filtered_airline_entities ae
  on asf.reporting_airline_oai_code = ae.airline_oai_code
left join air_oai_dims.airport_history ah
  on asf.depart_airport_oai_seq_id = ah.airport_oai_seq_id
WHERE ac.year_quarter_from_date
      between ae.source_from_date and coalesce(ae.source_thru_date, current_date);

-- 2. process DB1B Coupon data
-- 2.1. create table air_oai_facts.airfare_survey_coupon_load to stage the data
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_coupon_load;
CREATE TABLE air_oai_facts.airfare_survey_coupon_load
(
	  itinerary_oai_id             		bigint
	, market_oai_id						bigint
	, flight_pass_seq					integer
	, flight_pass_qty					integer
	, year_nbr              			integer
	, depart_airport_oai_id				integer
	, depart_airport_oai_seq_id			integer
	, depart_city_market_oai_id			integer
	, quarter_nbr              			integer
	, depart_airport_oai_code      		char(3)
	, depart_country_iso_code       	char(2)
	, depart_state_fips_code      		char(2)
	, depart_state_iso_code         	varchar(3)
	, depart_state_name      			varchar(75)
	, depart_world_area_oai_id        	integer
	, arrive_airport_oai_id				integer
	, arrive_airport_oai_seq_id			integer
	, arrive_city_market_oai_id			integer
	, arrive_airport_oai_code      		char(3)
	, arrive_country_iso_code       	char(2)
	, arrive_state_fips_code       		char(2)
	, arrive_state_iso_code         	varchar(3)
	, arrive_state_name        			varchar(75)
	, arrive_world_area_oai_id        	integer
	, trip_break_code             		char(1)
	, flight_pass_type					varchar(5)
	, ticketing_airline_oai_code 		varchar(3)
	, operating_airline_oai_code  		varchar(3)
	, reporting_airline_oai_code  		varchar(3)
	, passengers_qty          			real
	, airfare_class_code          		varchar(5)
	, distance_smi             			real
	, distance_group_id        			integer
	, gateway_ind              			real
	, itinerary_geo_type_id     		integer
	, coupon_geo_type_id        		integer
);
 
-- 2.2. ingest coupon csv data (Redshift COPY from S3)
-- single file:
--COPY air_oai_facts.airfare_survey_coupon_load
--FROM 's3://src-aviation/DB1B/coupon/CSV/Origin_and_Destination_Survey_DB1BCoupon_2025_1.csv.gz'
--IAM_ROLE default
--CSV GZIP
--DELIMITER ','
--IGNOREHEADER 1 
--REGION 'us-west-2'
--FILLRECORD;

-- multiple files 
COPY air_oai_facts.airfare_survey_coupon_load
FROM 's3://src-aviation/DB1B/coupon/CSV/'
IAM_ROLE default
CSV GZIP
DELIMITER ','
IGNOREHEADER 1
REGION 'us-west-2';
 
-- 2.3. create fact table air_oai_facts.airfare_survey_coupon
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_coupon;
CREATE TABLE air_oai_facts.airfare_survey_coupon
(
	  itinerary_oai_id             		bigint 		not null
	, flight_pass_seq					integer 	not null
	, year_quarter_start_date			date		not null
	, year_quarter_nbr					integer 	not null
	, market_oai_id						bigint 		not null
	, ticketing_airline_entity_id		integer		not null
	, ticketing_airline_entity_key		char(32)	not null
	, operating_airline_entity_id		integer		not null
	, operating_airline_entity_key		char(32)	not null
	, reporting_airline_entity_id		integer		not null
	, reporting_airline_entity_key		char(32)	not null
	, depart_airport_history_id			integer		not null
	, depart_airport_history_key		char(32)	not null
	, arrive_airport_history_id			integer		not null
	, arrive_airport_history_key		char(32)	not null
	, trip_break_code             		integer 	not null
	, gateway_ind              			integer 	not null
	, distance_group_oai_id        		integer 	not null
	, airfare_class_code          		char(1) 	not null
	, itinerary_geographic_type_oai_id  integer 	not null
	, coupon_geographic_type_oai_id     integer 	not null
	, flight_pass_type					char(1) 	not null
	, flight_pass_qty					integer 	not null
	, passengers_qty          			integer 	not null
	, distance_smi             			integer 	not null
	, created_by 						varchar(32)  not null
	, created_tmst 						timestamp    not null
	, updated_by 						varchar(32)
	, updated_tsmt 						timestamp
	, constraint airfare_survey_coupon_pk primary key (itinerary_oai_id, flight_pass_seq, year_quarter_start_date)
)
 
-- 2.5. insert data into fact table
INSERT INTO air_oai_facts.airfare_survey_coupon
(
	  itinerary_oai_id
	, flight_pass_seq
	, year_quarter_start_date
	, year_quarter_nbr
	, market_oai_id
	, ticketing_airline_entity_id
	, ticketing_airline_entity_key
	, operating_airline_entity_id
	, operating_airline_entity_key
	, reporting_airline_entity_id
	, reporting_airline_entity_key
	, depart_airport_history_id
	, depart_airport_history_key
	, arrive_airport_history_id
	, arrive_airport_history_key
	, trip_break_code
	, gateway_ind
	, distance_group_oai_id
	, airfare_class_code
	, itinerary_geographic_type_oai_id
	, coupon_geographic_type_oai_id
	, flight_pass_type
	, flight_pass_qty
	, passengers_qty
	, distance_smi
	, created_by
	, created_tmst
)
WITH filtered_airline_entities AS (
    SELECT airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    FROM air_oai_dims.airline_entities
    WHERE operating_region_code = 'Domestic'
)
SELECT ac.itinerary_oai_id
     , ac.flight_pass_seq
     , aq.year_quarter_from_date as year_quarter_start_date
	 , aq.year_quarter_nbr
	 , ac.market_oai_id
	 , aet.airline_entity_id     as ticketing_airline_entity_id
	 , aet.airline_entity_key    as ticketing_airline_entity_key
	 , aeo.airline_entity_id     as operating_airline_entity_id
	 , aeo.airline_entity_key    as operating_airline_entity_key
	 , aer.airline_entity_id     as reporting_airline_entity_id
	 , aer.airline_entity_key    as reporting_airline_entity_key
	 , ahd.airport_history_id    as depart_airport_history_id
	 , ahd.airport_history_key   as depart_airport_history_key
	 , aha.airport_history_id    as arrive_airport_history_id
	 , aha.airport_history_key   as arrive_airport_history_key
	 , case when ac.trip_break_code = 'X' then 1 else 0 end::smallint as trip_break_code
	 , ac.gateway_ind
	 , ac.distance_group_id
	 , ac.airfare_class_code
	 , ac.itinerary_geo_type_id  as itinerary_geographic_type_oai_id
	 , ac.coupon_geo_type_id     as coupon_geographic_type_oai_id
	 , ac.flight_pass_type
	 , ac.flight_pass_qty
	 , ac.passengers_qty
	 , ac.distance_smi
	 , current_user::varchar(32)
	 , current_timestamp::timestamp
FROM air_oai_facts.airfare_survey_coupon_load ac
join calendar_rs.gregorian_year_quarter aq
  ON ac.year_nbr = aq.year_nbr AND ac.quarter_nbr = aq.quarter_of_year_nbr
left join filtered_airline_entities aet
  on ac.ticketing_airline_oai_code = aet.airline_oai_code
left join filtered_airline_entities aeo
  on ac.operating_airline_oai_code = aeo.airline_oai_code
left join filtered_airline_entities aer
  on ac.reporting_airline_oai_code = aer.airline_oai_code
left join air_oai_dims.airport_history ahd
  on ac.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on ac.arrive_airport_oai_seq_id = aha.airport_oai_seq_id
where aq.year_quarter_from_date between aet.source_from_date and coalesce(aet.source_thru_date, current_date)
  AND aq.year_quarter_from_date between aeo.source_from_date and coalesce(aeo.source_thru_date, current_date)
  AND aq.year_quarter_from_date between aer.source_from_date and coalesce(aer.source_thru_date, current_date);


-- 3. process DB1B market data
-- 3.1. create table air_oai_facts.airfare_survey_market_load to stage the data
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_market_load;
CREATE TABLE air_oai_facts.airfare_survey_market_load
(
	  itinerary_oai_id              	bigint
	, market_oai_id                		bigint
	, market_coupon_qty		       		integer
	, year_nbr                 			integer
	, quarter_nbr              			integer
	, depart_airport_oai_id				integer
	, depart_airport_oai_seq_id			integer
	, depart_city_market_oai_id			integer
	, depart_airport_oai_code          	char(3)
	, depart_country_iso_code        	char(2)
	, depart_state_fips_code      		char(2)
	, depart_state_iso_code          	varchar(3)
	, depart_state_name      			varchar(75)
	, depart_world_area_oai_id          integer
	, arrive_airport_oai_id				integer
	, arrive_airport_oai_seq_id			integer
	, arrive_city_market_oai_id			integer
	, arrive_airport_oai_code        	char(3)
	, arrive_country_iso_code         	char(2)
	, arrive_state_fips_code        	char(2)
	, arrive_state_iso_code            	varchar(3)
	, arrive_state_name       			varchar(75)
	, arrive_world_area_oai_id          integer
	, airports_group_oai_code			varchar(255)
	, world_areas_group_oai_code		varchar(255)
	, ticketing_airline_change_ind		real
	, ticketing_airline_group_code		varchar(255)
	, operating_airline_change_ind		real
	, operating_airline_group_code		varchar(255)
	, reporting_airline_oai_code		varchar(3)
	, ticketing_airline_oai_code		varchar(3)
	, operating_airline_oai_code		varchar(3)
	, bulk_fare_ind						real
	, passenger_qty						real
	, market_fare_amt_usd				real
	, market_distance_smi				real
	, market_distance_group_oai_id		real
	, market_flown_distance_smi			real
	, non_stop_distance_smi				real
	, itinerary_geograhic_type_oai_id   integer
	, market_geograhic_type_oai_id      integer
);

-- 3.2. ingest market csv data (Redshift COPY from S3)
-- single file:
--COPY air_oai_facts.airfare_survey_market_load
--FROM 's3://src-aviation/DB1B/market/CSV/Origin_and_Destination_Survey_DB1BMarket_2024_2.csv.gz'
--IAM_ROLE default
--CSV GZIP
--DELIMITER ','
--IGNOREHEADER 1 
--REGION 'us-west-2'
--FILLRECORD;

-- multiple files 
COPY air_oai_facts.airfare_survey_market_load
FROM 's3://src-aviation/DB1B/market/CSV/'
IAM_ROLE default
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1
GZIP
REGION 'us-west-2';

-- 3.3. create fact table
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_market;
CREATE TABLE air_oai_facts.airfare_survey_market
(
	  itinerary_oai_id             		bigint 		not null
	, market_oai_id						bigint 		not null
	, year_quarter_start_date			date		not null
	, year_quarter_nbr					integer 	not null
	, ticketing_airline_entity_id		integer		not null
	, ticketing_airline_entity_key		char(32)	not null
	, ticketing_airline_change_ind		integer		not null
	, ticketing_airlines_group_code		varchar(55) not null
	, operating_airline_entity_id		integer		not null
	, operating_airline_entity_key		char(32)	not null
	, operating_airline_change_ind		smallint	not null
	, operating_airlines_group_code		varchar(55) not null
	, reporting_airline_entity_id		integer		not null
	, reporting_airline_entity_key		char(32)	not null
	, depart_airport_history_id			integer		not null
	, depart_airport_history_key		char(32)	not null
	, arrive_airport_history_id			integer		not null
	, arrive_airport_history_key		char(32)	not null
	, airports_group_oai_code			varchar(55) not null
	, world_areas_group_oai_code		varchar(55) not null
    , itinerary_geograhic_type_oai_id   integer 	not null
	, market_geograhic_type_oai_id      integer 	not null
	, market_distance_group_oai_id		integer 	not null
	, bulk_fare_ind						integer 	not null
	, market_coupon_qty					integer 	not null
	, passenger_qty						integer 	not null
	, market_fare_amount_usd			numeric(9,2) not null
	, market_distance_smi				integer 	not null
	, market_flown_distance_smi			integer 	not null
	, non_stop_distance_smi				integer 	not null
	, created_by 						varchar(32)  not null
	, created_tmst 						timestamp    not null
	, updated_by 						varchar(32)
	, updated_tsmt 						timestamp
	, constraint airfare_survey_market_pk primary key (itinerary_oai_id, market_oai_id, year_quarter_start_date)
)

-- 3.5. insert data into fact table
INSERT INTO air_oai_facts.airfare_survey_market
(
	  itinerary_oai_id
	, market_oai_id
	, year_quarter_start_date
	, year_quarter_nbr
	, ticketing_airline_entity_id
	, ticketing_airline_entity_key
	, ticketing_airline_change_ind
	, ticketing_airlines_group_code
	, operating_airline_entity_id
	, operating_airline_entity_key
	, operating_airline_change_ind
	, operating_airlines_group_code
	, reporting_airline_entity_id
	, reporting_airline_entity_key
	, depart_airport_history_id
	, depart_airport_history_key
	, arrive_airport_history_id
	, arrive_airport_history_key
	, airports_group_oai_code
	, world_areas_group_oai_code
	, itinerary_geograhic_type_oai_id
	, market_geograhic_type_oai_id
	, market_distance_group_oai_id
	, bulk_fare_ind
	, market_coupon_qty
	, passenger_qty
	, market_fare_amount_usd
	, market_distance_smi
	, market_flown_distance_smi
	, non_stop_distance_smi
	, created_by
	, created_tmst
)
WITH filtered_airline_entities AS (
    SELECT airline_oai_code, airline_entity_id, airline_entity_key, source_from_date, source_thru_date
    FROM air_oai_dims.airline_entities
    WHERE operating_region_code = 'Domestic'
)
SELECT am.itinerary_oai_id
	 , am.market_oai_id
	 , agq.year_quarter_from_date as year_quarter_start_date
	 , agq.year_quarter_nbr
     , aet.airline_entity_id      as ticketing_airline_entity_id
     , aet.airline_entity_key     as ticketing_airline_entity_key
	 , am.ticketing_airline_change_ind
	 , am.ticketing_airline_group_code
	 , aeo.airline_entity_id      as operating_airline_entity_id
	 , aeo.airline_entity_key     as operating_airline_entity_key
	 , am.operating_airline_change_ind
	 , am.operating_airline_group_code
	 , aer.airline_entity_id      as reporting_airline_entity_id
	 , aer.airline_entity_key     as reporting_airline_entity_key
	 , ahd.airport_history_id     as depart_airport_history_id
	 , ahd.airport_history_key    as depart_airport_history_key
     , aha.airport_history_id     as arrive_airport_history_id
     , aha.airport_history_key    as arrive_airport_history_key
	 , am.airports_group_oai_code
	 , am.world_areas_group_oai_code
	 , am.itinerary_geograhic_type_oai_id
	 , am.market_geograhic_type_oai_id
     , am.market_distance_group_oai_id
     , am.bulk_fare_ind
	 , am.market_coupon_qty
	 , am.passenger_qty
	 , am.market_fare_amt_usd
	 , am.market_distance_smi
	 , am.market_flown_distance_smi
	 , am.non_stop_distance_smi
	 , current_user::varchar(32)
	 , current_timestamp::timestamp
FROM air_oai_facts.airfare_survey_market_load am
join calendar_rs.gregorian_year_quarter agq
  ON am.year_nbr = agq.year_nbr AND am.quarter_nbr = agq.quarter_of_year_nbr
left join filtered_airline_entities aet
  on am.ticketing_airline_oai_code = aet.airline_oai_code
left join filtered_airline_entities aeo
  on am.operating_airline_oai_code = aeo.airline_oai_code
left join filtered_airline_entities aer
  on am.reporting_airline_oai_code = aer.airline_oai_code
left join air_oai_dims.airport_history ahd
  on am.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on am.arrive_airport_oai_seq_id = aha.airport_oai_seq_id
where  agq.year_quarter_from_date between aet.source_from_date and coalesce(aet.source_thru_date, current_date)
  AND agq.year_quarter_from_date between aeo.source_from_date and coalesce(aeo.source_thru_date, current_date)
  AND agq.year_quarter_from_date between aer.source_from_date and coalesce(aer.source_thru_date, current_date);

-- 4. create presentation layer views
create or replace view airlines_rs.airfare_survey_itinerary_v as
SELECT itinerary_oai_id, year_quarter_start_date, year_quarter_nbr
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, round_trip_fare_ind, online_purchase_ind, bulk_fare_ind, fare_credibility_ind
	, distance_group_oai_id, geographic_type_oai_id
	, coupon_qty, passenger_qty, distance_smi
	, flown_distance_smi, fare_per_person_usd, fare_per_mile_usd
FROM air_oai_facts.airfare_survey_itinerary;
 
create or replace view airlines_rs.airfare_survey_coupon_v as
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
 
create or replace view airlines_rs.airfare_survey_market_v as
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
