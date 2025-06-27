--The Airline Origin and Destination Survey (DB1B) is a 10% sample of airline tickets from reporting carriers collected by the Office of Airline Information of the Bureau of Transportation Statistics. Data includes origin, destination and other itinerary details of passengers transported. This database is used to determine air traffic patterns, air carrier market shares and passenger flows.

--Quarterly data 

--Details
--https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFI&Yv0x=D

--STEPS:
-- 0. download and unzip individual pre-zipped data files (stored by year and month) from https://transtats.bts.gov/PREZIP/

-- 1 Create extensions

-- 1 
--   1.3 Create table air_oai_facts.airfare_survey_ticket_load 
--   1.2 Copy DB1B data into
--   1.3 Create air_oai_facts.airfare_survey_itinerary
--   1.4 Create partioning airfare_survey_itinerary
--   1.5 Insert into airfare_survey_itinerary FROM airfare_survey_ticket_load; Join with airline_entities; airport_history 
-- 2
--   2.1 Create table a air_oai_facts.airfare_survey_coupon_load
--   2.2 Copy DB1B data into airfare_survey_coupon_load
--   2.3 Create air_oai_facts.airfare_survey_coupon
--   2.4 Create partioning air_oai_facts.airfare_survey_coupon
--   2.5 Insert into airfare_survey_coupon FROM airfare_survey_coupon_load; Join with airline_entities; airport_history 
-- 3 
--   3.1 Create table air_oai_facts.airfare_survey_market_load
--   3.1 Copy DB1B data into air_oai_facts.airfare_survey_market_load
--   3.2 Create table airfare_survey_market
--   3.4 Create partioning table airfare_survey_market
--   3.5 Insert into airfare_survey_market_load into airfare_survey_market. Join airline_entities; airport_history
-- 4 Create create primary key and index on the tables
-- 5 Vacuum on the table
-- 6 Validation

-- SCRIPT STARTS HERE

-- 1.1 Create table air_oai_facts.airfare_survey_ticket_load  

create table air_oai_facts.airfare_survey_ticket_load
( itinerary_oai_id								bigint null
	, coupon_qty									float4 null
	, year_nbr										integer null
	, quarter_nbr									integer null
	, depart_airport_oai_code						char(3) null
	, depart_airport_oai_id							integer null
	, depart_airport_oai_seq_id						integer null
	, depart_market_city_oai_id						integer null
	, depart_country_iso_code						char(2) null
	, depart_subdivision_fips_code					char(2) null
	, depart_subdivision_iso_code         			varchar(3) null
	, depart_subdivision_name						varchar(75) null
	, depart_wac_oai_id								integer null
	, round_trip_ind            					float4 null
	, online_ind									float4 null
	, fare_credibility_ind							float4 null
	, fare_per_smi									float4 null
	, reporting_airline_oai_code					varchar(3) null
	, passenger_qty           						float4 null
	, fare_per_person_amount_usd					float4 null
	, bulk_fare_ind									float4 null
	, distance_smi									float4 null
	, distance_group_oai_id							integer null
	, flown_distance_smi							float4 null
	, geographic_type_oai_id						integer null
	, filler										varchar(10) null
	);
-- 1.2 Copy DB1B data into airfare_survey_ticket_load
-- for x in $(ls /tmp/DB1B/_ticket/*.csv);
-- do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY  air_oai_facts.airfare_survey_ticket_load FROM '$x' CSV HEADER"; done ;

---AWS Aurora SQL
SELECT aws_s3.table_import_from_s3(
    'air_oai_facts.airfare_survey_ticket_load', 
    '', 
    '(FORMAT CSV, HEADER true, QUOTE ''"'')',
    aws_commons.create_s3_uri(
        'src-aviation', 
        'DB1B/ticket/CSV/Origin_and_Destination_Survey_DB1BMTicket_2023_1.csv.gz', 
        'us-west-2'
    )
);
--   1.3 Create air_oai_facts.airfare_survey_itinerary

create table air_oai_facts.airfare_survey_itinerary
	 ( itinerary_oai_id								bigint  not null
	 , year_quarter_start_date						date	not null
	 , reporting_airline_entity_id					smallint not null
	 , reporting_airline_entity_key					char(32) not null
	 , depart_airport_history_id					integer	not null
	 , depart_airport_history_key					char(32) not null
	 , round_trip_fare_ind            				smallint null
	 , online_purchase_ind							smallint null
	 , bulk_fare_ind								smallint null
	 , fare_credibility_ind							smallint null
	 , distance_group_oai_id						smallint null
	 , geographic_type_oai_id						smallint null
	 , coupon_qty									smallint null
	 , passenger_qty           						smallint null
	 , distance_smi									integer null
	 , flown_distance_smi							integer null
	 , fare_per_person_usd							integer null
	 , fare_per_mile_usd							numeric(10,5) null
	 , created_by 									varchar(32) DEFAULT 'CURRENT_USER' NOT NULL
	 , created_tmst 								timestamp(0) DEFAULT CURRENT_TIMESTAMP NOT NULL
	 , updated_by 									varchar(32)
	 , updated_tsmt 								timestamp(0)
	 , constraint airfare_survey_itinerary_pk primary key (itinerary_oai_id, year_quarter_start_date)
	 ) partition by range (year_quarter_start_date)
	 ;

--   1.4 Create partioning airfare_survey_itinerary
DO $$
DECLARE
    year_val INT;
    quarter_val INT;
    start_date DATE;
    end_date DATE;
    table_name TEXT;
    sql_stmt TEXT;
BEGIN
    FOR year_val IN 1993..2024 LOOP
        FOR quarter_val IN 1..4 LOOP
            -- Skip future quarters in 2024
            IF (year_val = 2024 AND quarter_val > 1) THEN
                CONTINUE;
            END IF;
            
            -- Calculate start and end dates for the quarter
            start_date := make_date(year_val, (quarter_val - 1) * 3 + 1, 1);
            
            -- Calculate end date (first day of next quarter minus 1 day)
            IF quarter_val = 4 THEN
                end_date := make_date(year_val + 1, 1, 1);
            ELSE
                end_date := make_date(year_val, quarter_val * 3 + 1, 1);
            END IF;
            
            -- Create table name
            table_name := 'air_oai_facts.airfare_survey_itinerary_' || year_val || 'Q' || quarter_val;
            
            -- Build and execute SQL statement
            sql_stmt := 'CREATE TABLE ' || table_name || 
                       ' PARTITION OF air_oai_facts.airfare_survey_coupon FOR VALUES FROM (''' || 
                       start_date || ''') TO (''' || end_date || ''');';
            
            RAISE NOTICE '%', sql_stmt;
            EXECUTE sql_stmt;
        END LOOP;
    END LOOP;
END $$;

	 
--   1.5 Insert into airfare_survey_itinerary FROM airfare_survey_ticket_load; Join with airline_entities; airport_history 

INSERT INTO air_oai_facts.airfare_survey_itinerary
	( itinerary_oai_id, year_quarter_start_date
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, round_trip_fare_ind, online_purchase_ind, bulk_fare_ind, fare_credibility_ind
	, distance_group_oai_id, geographic_type_oai_id
	, coupon_qty, passenger_qty, distance_smi, flown_distance_smi
	, fare_per_person_usd, fare_per_mile_usd
	, created_by, created_tmst)
SELECT asf.itinerary_oai_id
	 , (asf.year_nbr::text || case when asf.quarter_nbr = 1 then '-01-01' when asf.quarter_nbr = 2 then '-04-01' 
            when asf.quarter_nbr = 3 then '-07-01' when asf.quarter_nbr = 4 then '-10-01' else null end::text)::date as year_quarter_start_date
     , ae.airline_entity_id as reporting_airline_entity_id
     , ae.airline_entity_key as reporting_airline_entity_key
     , ah.airport_history_id as depart_airport_history_id
     , ah.airport_history_key as depart_airport_history_key
     , round_trip_ind, online_ind, bulk_fare_ind, fare_credibility_ind
     , distance_group_oai_id, geographic_type_oai_id
	 , coupon_qty, passenger_qty, distance_smi, flown_distance_smi
	 , fare_per_person_amount_usd, fare_per_smi
	 , current_user, now()
FROM air_oai_facts.airfare_survey_ticket_load asf
-- air_oai_facts.airfare_survey_ticket_fdw asf
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') ae 
  on asf.reporting_airline_oai_code = ae.airline_oai_code
left join air_oai_dims.airport_history ah
  on asf.depart_airport_oai_seq_id = ah.airport_oai_seq_id
where (asf.year_nbr::text || 
      case when asf.quarter_nbr = 1 then '-01-01' when asf.quarter_nbr = 2 then '-04-01' 
           when asf.quarter_nbr = 3 then '-07-01' when asf.quarter_nbr = 4 then '-10-01' else null end::text)::date
      between ae.source_from_date and coalesce(ae.source_thru_date, current_date)
	  

--   2.1 Create table a air_oai_facts.airfare_survey_coupon_load

create table air_oai_facts.airfare_survey_coupon_load
	( itinerary_oai_id             		bigint null
	, market_oai_id						bigint null
	, flight_pass_seq					integer null
	, flight_pass_qty					integer null
	, year_nbr              			integer null
	, depart_airport_oai_id				integer null
	, depart_airport_oai_seq_id			integer null
	, depart_city_market_oai_id			integer null
	, quarter_nbr              			integer null
	, depart_airport_oai_code      		char(3) null
	, depart_country_iso_code       	char(2) null
	, depart_state_fips_code      		char(2) null
	, depart_state_iso_code         	varchar(3) null
	, depart_state_name      			varchar(75) null
	, depart_world_area_oai_id        	integer null
	, arrive_airport_oai_id				integer null
	, arrive_airport_oai_seq_id			integer	null
	, arrive_city_market_oai_id			integer null
	, arrive_airport_oai_code      		char(3) null
	, arrive_country_iso_code       	char(2) null
	, arrive_state_fips_code       		char(2) null
	, arrive_state_iso_code         	varchar(3) null
	, arrive_state_name        			varchar(75) null
	, arrive_world_area_oai_id        	integer null
	, trip_break_code             		char(1) null
	, flight_pass_type					varchar(5) null
	, ticketing_airline_oai_code 		varchar(3) null
	, operating_airline_oai_code  		varchar(3) null
	, reporting_airline_oai_code  		varchar(3) null
	, passengers_qty          			float4 null
	, airfare_class_code          		varchar(5) null
	, distance_smi             			float4 null
	, distance_group_id        			integer null
	, gateway_ind              			float4 null
	, itinerary_geo_type_id     		integer null
	, coupon_geo_type_id        		integer null
	, filler							varchar(10) null
	)

--   2.2 Copy DB1B data into airfare_survey_coupon_load
--for x in $(ls /tmp/DB1B/_coupon/*.csv);
-- do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY  air_oai_facts.airfare_survey_coupon_load FROM '$x' CSV HEADER"; done ;

---AWS Aurora

SELECT aws_s3.table_import_from_s3(
    'air_oai_facts.airfare_survey_coupon_load', 
    '', 
    '(FORMAT CSV, HEADER true, QUOTE ''"'')',
    aws_commons.create_s3_uri(
        'src-aviation', 
        'DB1B/coupon/CSV/Origin_and_Destination_Survey_DB1BCoupon_2023_1.csv.gz', 
        'us-west-2'
    )
);

--   2.3 Create air_oai_facts.airfare_survey_coupon

create table air_oai_facts.airfare_survey_coupon
	( itinerary_oai_id             		bigint 		not null
	, flight_pass_seq					integer 	not null
	, year_quarter_start_date			date		not null
	, market_oai_id						bigint 		not null
	, ticketing_airline_entity_id		smallint	not null
	, ticketing_airline_entity_key		char(32)	not null
	, operating_airline_entity_id		smallint	not null
	, operating_airline_entity_key		char(32)	not null
	, reporting_airline_entity_id		smallint	not null
	, reporting_airline_entity_key		char(32)	not null
	, depart_airport_history_id			integer		not null
	, depart_airport_history_key		char(32)	not null
	, arrive_airport_history_id			integer		not null
	, arrive_airport_history_key		char(32)	not null
	, trip_break_code             		smallint 	not null
	, gateway_ind              			smallint 	not null
	, distance_group_oai_id        		smallint 	not null
	, airfare_class_code          		char(1) 	not null
	, itinerary_geographic_type_oai_id  smallint 	not null
	, coupon_geographic_type_oai_id     smallint 	not null
	, flight_pass_type					char(1) 	not null
	, flight_pass_qty					smallint 	not null
	, passengers_qty          			smallint 	not null
	, distance_smi             			integer 	not null
	, created_by 						varchar(32) DEFAULT 'CURRENT_USER' NOT NULL
	, created_tmst 						timestamp(0) DEFAULT CURRENT_TIMESTAMP NOT NULL
	, updated_by 						varchar(32)
	, updated_tsmt 						timestamp(0)
	, constraint airfare_survey_coupon_pk primary key (itinerary_oai_id, flight_pass_seq, year_quarter_start_date)
	) partition by range (year_quarter_start_date)
	;

--   2.4 Create partioning air_oai_facts.airfare_survey_coupon
DO $$
DECLARE
    year_val INT;
    quarter_val INT;
    start_date DATE;
    end_date DATE;
    table_name TEXT;
    sql_stmt TEXT;
BEGIN
    FOR year_val IN 1993..2024 LOOP
        FOR quarter_val IN 1..4 LOOP
            -- Skip future quarters in 2024
            IF (year_val = 2024 AND quarter_val > 1) THEN
                CONTINUE;
            END IF;
            
            -- Calculate start and end dates for the quarter
            start_date := make_date(year_val, (quarter_val - 1) * 3 + 1, 1);
            
            -- Calculate end date (first day of next quarter minus 1 day)
            IF quarter_val = 4 THEN
                end_date := make_date(year_val + 1, 1, 1);
            ELSE
                end_date := make_date(year_val, quarter_val * 3 + 1, 1);
            END IF;
            
            -- Create table name
            table_name := 'air_oai_facts.airfare_survey_coupon_' || year_val || 'Q' || quarter_val;
            
            -- Build and execute SQL statement
            sql_stmt := 'CREATE TABLE ' || table_name || 
                       ' PARTITION OF air_oai_facts.airfare_survey_coupon FOR VALUES FROM (''' || 
                       start_date || ''') TO (''' || end_date || ''');';
            
            RAISE NOTICE '%', sql_stmt;
            EXECUTE sql_stmt;
        END LOOP;
    END LOOP;
END $$;

--   2.5 Insert into airfare_survey_coupon FROM airfare_survey_coupon_load; Join with airline_entities; airport_history 
INSERT INTO air_oai_facts.airfare_survey_coupon
	(itinerary_oai_id, flight_pass_seq, year_quarter_start_date, market_oai_id
	, ticketing_airline_entity_id, ticketing_airline_entity_key
	, operating_airline_entity_id, operating_airline_entity_key
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_history_id, arrive_airport_history_key
	, trip_break_code, gateway_ind, distance_group_oai_id, airfare_class_code
	, itinerary_geographic_type_oai_id, coupon_geographic_type_oai_id
	, flight_pass_type, flight_pass_qty, passengers_qty, distance_smi
	, created_by, created_tmst)
SELECT ac.itinerary_oai_id
     , ac.flight_pass_seq
     , (ac.year_nbr::text || case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01' 
            when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date as year_quarter_start_date
	 , ac.market_oai_id
	 , aet.airline_entity_id as ticketing_airline_entity_id
	 , aet.airline_entity_key as ticketing_airline_entity_key
	 , aeo.airline_entity_id as operating_airline_entity_id
	 , aeo.airline_entity_key as operating_airline_entity_key
	 , aer.airline_entity_id as reporting_airline_entity_id
	 , aer.airline_entity_key as reporting_airline_entity_key
	 , ahd.airport_history_id as depart_airport_history_id
	 , ahd.airport_history_key as depart_airport_history_key
	 , aha.airport_history_id as arrive_airport_history_id
	 , ahd.airport_history_key as arrive_airport_history_key
	 , case when ac.trip_break_code = 'X' then 1 else 0 end::smallint as trip_break_code
	 , ac.gateway_ind
	 , ac.distance_group_id
	 , ac.airfare_class_code
	 , ac.itinerary_geo_type_id as itinerary_geographic_type_id
	 , ac.coupon_geo_type_id as coupon_geographic_type_id
	 , ac.flight_pass_type
	 , ac.flight_pass_qty
	 , ac.passengers_qty
	 , ac.distance_smi
	 , current_user
	 , current_timestamp
FROM air_oai_facts.airfare_survey_coupon_load ac
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aet
  on ac.ticketing_airline_oai_code = aet.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aeo
  on ac.operating_airline_oai_code = aeo.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aer
  on ac.reporting_airline_oai_code = aer.airline_oai_code
left join air_oai_dims.airport_history ahd
  on ac.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on ac.arrive_airport_oai_seq_id = aha.airport_oai_seq_id
where (ac.year_nbr::text || 
       case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01' 
       when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aet.source_from_date and coalesce(aet.source_thru_date, current_date)
and   (ac.year_nbr::text || 
       case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01' 
       when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aeo.source_from_date and coalesce(aeo.source_thru_date, current_date)
and   (ac.year_nbr::text || 
       case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01' 
       when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aer.source_from_date and coalesce(aer.source_thru_date, current_date)
;


-- 3.1 Create table air_oai_facts.airfare_survey_market_load
create table air_oai_facts.airfare_survey_market_load
	( itinerary_oai_id              	bigint null
	, market_oai_id                		bigint null
	, market_coupon_qty		       		integer null
	, year_nbr                 			integer null
	, quarter_nbr              			integer null
	, depart_airport_oai_id				integer null
	, depart_airport_oai_seq_id			integer null
	, depart_city_market_oai_id			integer null
	, depart_airport_oai_code          	char(3) null
	, depart_country_iso_code        	char(2) null
	, depart_state_fips_code      		char(2) null
	, depart_state_iso_code          	varchar(3) null
	, depart_state_name      			varchar(75) null
	, depart_world_area_oai_id          integer null
	, arrive_airport_oai_id				integer null
	, arrive_airport_oai_seq_id			integer	null
	, arrive_city_market_oai_id			integer null
	, arrive_airport_oai_code        	char(3) null
	, arrive_country_iso_code         	char(2) null
	, arrive_state_fips_code        	char(2) null
	, arrive_state_iso_code            	varchar(3) null
	, arrive_state_name       			varchar(75) null
	, arrive_world_area_oai_id          integer null
	, airports_group_oai_code			varchar(255) null
	, world_areas_group_oai_code		varchar(255) null
	, ticketing_airline_change_ind		float4 null
	, ticketing_airline_group_code		varchar(255) null
	, operating_airline_change_ind		float4 null
	, operating_airline_group_code		varchar(255) null
	, reporting_airline_oai_code		varchar(3) null
	, ticketing_airline_oai_code		varchar(3) null
	, operating_airline_oai_code		varchar(3) null
	, bulk_fare_ind						float4 null
	, passenger_qty						float4 null
	, market_fare_amt_usd				float4 null
	, market_distance_smi				float4 null
	, market_distance_group_oai_id		float4 null
	, market_flown_distance_smi			float4 null
	, non_stop_distance_smi				float4 null
	, itinerary_geograhic_type_oai_id   integer null
	, market_geograhic_type_oai_id      integer null
	, filler							varchar(10) null
	)
	
--   3.1 Copy DB1B data into air_oai_facts.airfare_survey_market_load
	
--for x in $(ls /tmp/DB1B/_market/*.csv);
-- do mstr_psql -d aviation -h 127.0.0.1 -U mstr -c "COPY  air_oai_facts.airfare_survey_market_load FROM '$x' CSV HEADER"; done ;

--- AWS Aurora SQL
SELECT aws_s3.table_import_from_s3(
    'air_oai_facts.airfare_survey_market_load', 
    '', 
    '(FORMAT CSV, HEADER true, QUOTE ''"'')',
    aws_commons.create_s3_uri(
        'src-aviation', 
        'DB1B/market/CSV/Origin_and_Destination_Survey_DB1BMarket_2023_1.csv.gz', 
        'us-west-2'
    )
);


	
--   3.2 Create table airfare_survey_market

create table air_oai_facts.airfare_survey_market
	( itinerary_oai_id             		bigint 		not null
	, market_oai_id						bigint 		not null
	, year_quarter_start_date			date		not null
	, ticketing_airline_entity_id		smallint	not null
	, ticketing_airline_entity_key		char(32)	not null
	, ticketing_airline_change_ind		smallint	not null
	, ticketing_airlines_group_code		varchar(55) not null
	, operating_airline_entity_id		smallint	not null
	, operating_airline_entity_key		char(32)	not null
	, operating_airline_change_ind		smallint	not null
	, operating_airlines_group_code		varchar(55) not null
	, reporting_airline_entity_id		smallint	not null
	, reporting_airline_entity_key		char(32)	not null
	, depart_airport_history_id			integer		not null
	, depart_airport_history_key		char(32)	not null
	, arrive_airport_history_id			integer		not null
	, arrive_airport_history_key		char(32)	not null
	, airports_group_oai_code			varchar(55) not null
	, world_areas_group_oai_code		varchar(55) not null
    , itinerary_geograhic_type_oai_id   smallint 	not null
	, market_geograhic_type_oai_id      smallint 	not null
	, market_distance_group_oai_id		smallint 	not null
	, bulk_fare_ind						smallint 	not null
	, market_coupon_qty					smallint 	not null
	, passenger_qty						smallint 	not null
	, market_fare_amount_usd			numeric(9,2) not null
	, market_distance_smi				integer 	not null
	, market_flown_distance_smi			integer 	not null
	, non_stop_distance_smi				integer 	not null
	, created_by 						varchar(32) DEFAULT 'CURRENT_USER' NOT NULL
	, created_tmst 						timestamp(0) DEFAULT CURRENT_TIMESTAMP NOT NULL
	, updated_by 						varchar(32)
	, updated_tsmt 						timestamp(0)
	, constraint airfare_survey_market_pk primary key (itinerary_oai_id, market_oai_id, year_quarter_start_date)
	) partition by range (year_quarter_start_date)
	;


--   3.4 Create partioning table airfare_survey_market

DO $$
DECLARE
    year_val INT;
    quarter_val INT;
    start_date DATE;
    end_date DATE;
    table_name TEXT;
    sql_stmt TEXT;
BEGIN
    FOR year_val IN 1993..2024 LOOP
        FOR quarter_val IN 1..4 LOOP
            -- Skip future quarters in 2024
            IF (year_val = 2024 AND quarter_val > 1) THEN
                CONTINUE;
            END IF;
            
            -- Calculate start and end dates for the quarter
            start_date := make_date(year_val, (quarter_val - 1) * 3 + 1, 1);
            
            -- Calculate end date (first day of next quarter minus 1 day)
            IF quarter_val = 4 THEN
                end_date := make_date(year_val + 1, 1, 1);
            ELSE
                end_date := make_date(year_val, quarter_val * 3 + 1, 1);
            END IF;
            
            -- Create table name
            table_name := 'air_oai_facts.airfare_survey_market_' || year_val || 'Q' || quarter_val;
            
            -- Build and execute SQL statement
            sql_stmt := 'CREATE TABLE ' || table_name || 
                       ' PARTITION OF air_oai_facts.airfare_survey_coupon FOR VALUES FROM (''' || 
                       start_date || ''') TO (''' || end_date || ''');';
            
            RAISE NOTICE '%', sql_stmt;
            EXECUTE sql_stmt;
        END LOOP;
    END LOOP;
END $$;
--   3.5 Insert into airfare_survey_market_load into airfare_survey_market. Join airline_entities; airport_history

INSERT INTO air_oai_facts.airfare_survey_market
	( itinerary_oai_id, market_oai_id, year_quarter_start_date
	, ticketing_airline_entity_id, ticketing_airline_entity_key, ticketing_airline_change_ind, ticketing_airlines_group_code
	, operating_airline_entity_id, operating_airline_entity_key, operating_airline_change_ind, operating_airlines_group_code
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_history_id, arrive_airport_history_key
	, airports_group_oai_code, world_areas_group_oai_code
	, itinerary_geograhic_type_oai_id, market_geograhic_type_oai_id, market_distance_group_oai_id
	, bulk_fare_ind, market_coupon_qty, passenger_qty, market_fare_amount_usd
	, market_distance_smi, market_flown_distance_smi, non_stop_distance_smi
	, created_by, created_tmst)
SELECT am.itinerary_oai_id
	 , am.market_oai_id
	 , (am.year_nbr::text || case when am.quarter_nbr = 1 then '-01-01' when am.quarter_nbr = 2 then '-04-01' 
            when am.quarter_nbr = 3 then '-07-01' when am.quarter_nbr = 4 then '-10-01' else null end::text)::date as year_quarter_start_date
     , aet.airline_entity_id as ticketing_airline_entity_id
     , aet.airline_entity_key as ticketing_airline_entity_key
	 , am.ticketing_airline_change_ind
	 , am.ticketing_airline_group_code
	 , aeo.airline_entity_id as operating_airline_entity_id
	 , aeo.airline_entity_key as operating_airline_entity_key
	 , am.operating_airline_change_ind
	 , am.operating_airline_group_code
	 , aer.airline_entity_id as reporting_airline_entity_id
	 , aer.airline_entity_key as reporting_airline_entity_key
	 , ahd.airport_history_id as depart_airport_history_id
	 , ahd.airport_history_key as depart_airport_history_key
     , aha.airport_history_id as arrive_airport_history_id
     , aha.airport_history_key as arrive_airport_history_key
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
	 , current_user
	 , current_timestamp
FROM air_oai_facts.airfare_survey_market_load am
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aet
  on am.ticketing_airline_oai_code = aet.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aeo
  on am.operating_airline_oai_code = aeo.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aer
  on am.reporting_airline_oai_code = aer.airline_oai_code
left join air_oai_dims.airport_history ahd
  on am.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
  on am.arrive_airport_oai_seq_id = aha.airport_oai_seq_id
where (am.year_nbr::text || 
       case when am.quarter_nbr = 1 then '-01-01' when am.quarter_nbr = 2 then '-04-01' 
       when am.quarter_nbr = 3 then '-07-01' when am.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aet.source_from_date and coalesce(aet.source_thru_date, current_date)
and   (am.year_nbr::text || 
       case when am.quarter_nbr = 1 then '-01-01' when am.quarter_nbr = 2 then '-04-01' 
       when am.quarter_nbr = 3 then '-07-01' when am.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aeo.source_from_date and coalesce(aeo.source_thru_date, current_date)
and   (am.year_nbr::text || 
       case when am.quarter_nbr = 1 then '-01-01' when am.quarter_nbr = 2 then '-04-01' 
       when am.quarter_nbr = 3 then '-07-01' when am.quarter_nbr = 4 then '-10-01' else null end::text)::date
       between aer.source_from_date and coalesce(aer.source_thru_date, current_date)
;


-- 5 create an primary key and index
alter table oai.airfare_survey_itinerary add constraint airfare_survey_itinerary_pk primary key (itinerary_id);
create index airfare_survey_itinerary_reporting_carrier_idx on oai.airfare_survey_itinerary (reporting_carrier_iata_cd);
create index airfare_survey_itinerary_origin_airport_idx on oai.airfare_survey_itinerary (orig_airport_iata_cd);
create index airfare_survey_itinerary_year_quarter_idx on oai.airfare_survey_itinerary (year_nbr, quarter_nbr);

-- 6. Vacuum on the tables

VACUUM VERBOSE air_oai_facts.airfare_survey_itinerary;
vacuum verbose air_oai_facts.airfare_survey_coupon;
VACUUM VERBOSE air_oai_facts.airfare_survey_market;

-- 7 Validation
