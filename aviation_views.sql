create schema if not exists airlines_pg;

-- drop view if exists airlines_pg.airline_flights_scheduled_v;
create or replace view airlines_pg.airline_flights_scheduled_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min
FROM air_oai_facts.airline_flights_scheduled;

-- drop view if exists airlines_pg.airline_flights_completed_v;
create or replace view airlines_pg.airline_flights_completed_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::date as actual_arrive_date_lcl
	, actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::date as actual_arrive_date_utc
	, actual_elapsed_time_min
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::date as wheels_on_date_lcl
	, wheels_on_tmstz_utc, wheels_on_tmstz_utc::date as wheels_on_date_utc
	, airborne_time_min, taxi_out_min, taxi_in_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
	, airline_delay_min, weather_delay_min, nas_delay_min, security_delay_min, late_aircraft_delay_min
FROM air_oai_facts.airline_flights_completed;

-- drop view if exists airlines_pg.airline_flights_cancelled_v;
create or replace view airlines_pg.airline_flights_cancelled_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, taxi_out_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
FROM air_oai_facts.airline_flights_cancelled;

/*
select * from air_oai_dims.airline_entities where airline_oai_code = 'DL';

select * from air_oai_dims.airport_history where airport_oai_code = 'NRT'; -- GUID
-- KEY is MD5 Hash of IATA Code + Effective Date.  OAI ~ IATA

select count(*) from air_oai_dims.airport_history; -- 19132
select count(*) from air_oai_dims.airport_history where airport_latest_ind = 1; -- 6644
select count(*) from air_oai_facts.airline_flights_scheduled; -- 7142354
*/


-- drop view if exists airlines_pg.airline_flights_diverted_v;
create or replace view airlines_pg.airline_flights_diverted_v as
SELECT flight_key, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_from_date, arrive_airport_history_id, arrive_airport_history_key
	, distance_smi, distance_nmi, distance_kmt, distance_group_id
	, depart_time_block, arrive_time_block
	, report_depart_tmstz_lcl, report_depart_tmstz_lcl::date as report_depart_date_lcl
	, report_depart_tmstz_utc, report_depart_tmstz_utc::date as report_depart_date_utc
	, report_arrive_tmstz_lcl, report_arrive_tmstz_lcl::date as report_arrive_date_lcl
	, report_arrive_tmstz_utc, report_arrive_tmstz_utc::date as report_arrive_date_utc
	, report_elapsed_time_min, flight_status
	, actual_depart_tmstz_lcl, actual_depart_tmstz_lcl::date as actual_depart_date_lcl
	, actual_depart_tmstz_utc, actual_depart_tmstz_utc::date as actual_depart_date_utc
	, actual_arrive_tmstz_lcl, actual_arrive_tmstz_lcl::date as actual_arrive_date_lcl
	, actual_arrive_tmstz_utc, actual_arrive_tmstz_utc::date as actual_arrive_date_utc
	, actual_elapsed_time_min
	, wheels_off_tmstz_lcl, wheels_off_tmstz_lcl::date as wheels_off_date_lcl
	, wheels_off_tmstz_utc, wheels_off_tmstz_utc::date as wheels_off_date_utc
	, wheels_on_tmstz_lcl, wheels_on_tmstz_lcl::date as wheels_on_date_lcl
	, wheels_on_tmstz_utc, wheels_on_tmstz_utc::date as wheels_on_date_utc
	, airborne_time_min, taxi_out_min, taxi_in_min
	, first_gate_depart_tmstz_lcl, first_gate_depart_tmstz_utc
	, total_ground_time, longest_ground_time
FROM airlines_pg.air_oai_facts.airline_flights_diverted;

-- drop view if exists airlines_pg.airline_flights_diverted_legs_v:
create or replace view airlines_pg.airline_flights_diverted_legs_v as
SELECT flight_key, diversion_nbr, flight_date
	, airline_oai_code, airline_entity_from_date, airline_entity_id, airline_entity_key
	, flight_nbr, flight_count, tail_nbr
	, depart_airport_oai_code, depart_airport_from_date, depart_airport_history_id, depart_airport_history_key
	, original_arrive_airport_oai_code, original_arrive_airport_from_date, original_arrive_airport_history_id, original_arrive_airport_history_key
	, diverted_airport_oai_code, diverted_airport_from_date, diverted_airport_history_id, diverted_airport_history_key
	, diverted_tail_nbr
	, diverted_wheels_on_tmstz_lcl, diverted_wheels_on_tmstz_utc
	, diverted_wheels_off_tmstz_lcl, diverted_wheels_off_tmstz_utc
	, diverted_total_ground_time_min, diverted_longest_ground_time_min
FROM air_oai_facts.airline_flights_diverted_legs;

-- drop view if exists airlines_pg.airline_traffic_market_v:
create or replace view airlines_pg.airline_traffic_market_v as
SELECT airline_traffic_market_key, year_month_nbr
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, service_class_code, data_source_code
	, passengers_qty, freight_kgm, mail_kgm
	--, t100_records_qty
FROM air_oai_facts.airline_traffic_market;

-- drop view if exists airlines_pg.airline_traffic_segment_v:
create or replace view airlines_pg.airline_traffic_segment_v as
SELECT airline_traffic_segment_key, year_month_nbr, service_class_code
	, airline_oai_code, airline_effective_date, airline_entity_id, airline_entity_key
	, depart_airport_oai_code, depart_airport_effective_date, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_oai_code, arrive_airport_effective_date, arrive_airport_history_id, arrive_airport_history_key
	, aircraft_type_oai_nbr, aircraft_configuration_ref
	, data_source_code
	, scheduled_departures_qty, performed_departures_qty
	, available_seat_qty, passengers_qty, freight_kgm, mail_kgm
	, ramp_to_ramp_min, air_time_min
	--, t100_records_qty
FROM air_oai_facts.airline_traffic_segment;

-- drop view if exists airlines_pg.airfare_survey_itinerary_v:
create or replace view airlines_pg.airfare_survey_itinerary_v as
SELECT itinerary_oai_id, year_quarter_start_date, year_quarter_nbr
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, round_trip_fare_ind, online_purchase_ind, bulk_fare_ind, fare_credibility_ind
	, distance_group_oai_id, geographic_type_oai_id
	, coupon_qty, passenger_qty, distance_smi
	, flown_distance_smi, fare_per_person_usd, fare_per_mile_usd
FROM air_oai_facts.airfare_survey_itinerary;

-- drop view if exists airlines_pg.airfare_survey_coupon_v:
create or replace view airlines_pg.airfare_survey_coupon_v as
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

-- select itinerary_oai_id, flight_pass_seq, count(*) from airlines_pg.airfare_survey_coupon_v group by 1,2 having count(*) > 1 order by count(*) desc;

-- drop view if exists airlines_pg.airfare_survey_market_v:
create or replace view airlines_pg.airfare_survey_market_v as
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

-- select market_oai_id, count(*) from airlines_pg.airfare_survey_market_v group by 1 having count(*) > 1 order by count(*) desc;

----------
-- DIMS --
----------

-- drop view if exists airlines_pg.aircraft_configurations_v:
create or replace view airlines_pg.aircraft_configurations_v as
SELECT aircraft_configuration_ref
	 , aircraft_configuration_descr
FROM air_oai_dims.aircraft_configurations;

-- drop view if exists airlines_pg.aircraft_types_v:
create or replace view airlines_pg.aircraft_types_v as
SELECT aircraft_type_oai_nbr
	 , aircraft_group_oai_nbr
	 , aircraft_oai_type
	 , manufacturer_name
	 , aircraft_type_long_name
	 , aircraft_type_brief_name
	 , aircraft_type_from_date
	 , aircraft_type_thru_date
FROM air_oai_dims.aircraft_types;

-- drop view if exists airlines_pg.airline_entities_v:
create or replace view airlines_pg.airline_entities_v as
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

-- drop view if exists airlines_pg.airline_entities_current_v:
create or replace view airlines_pg.airline_entities_current_v as
SELECT --airline_entity_id, airline_entity_key
	 airline_oai_code
	, airline_usdot_id
	, entity_oai_code
	, airline_name
	--, airline_unique_oai_code
	--, entity_unique_oai_code
	--, airline_unique_name
	, world_area_oai_id
	, world_area_oai_seq_id
	, airline_old_group_nbr
	, airline_new_group_nbr
	, operating_region_code
	--, source_from_date
	--, source_thru_date
FROM air_oai_dims.airline_entities
where source_thru_date is null;

-- drop view if exists airlines_pg.airline_service_classes_v;
create or replace view airlines_pg.airline_service_classes_v as
SELECT service_class_code
	, scheduled_ind
	, chartered_ind
	, service_class_descr
FROM air_oai_dims.airline_service_classes;

-- drop view if exists airlines_pg.airport_history_v;
create or replace view airlines_pg.airport_history_v as
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

-- drop view if exists airlines_pg.airport_current_v;
create or replace view airlines_pg.airport_current_v as
SELECT -- airport_history_id, airport_history_key,
      airport_oai_code -- , effective_from_date, effective_thru_date
	, airport_closed_ind
	-- , airport_latest_ind, airport_oai_seq_id
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

/*
select airport_history_id, airport_display_name, airport_oai_code, city_full_display_name, market_city_full_display_name 
from airlines_pg.airport_history_v
where city_full_display_name != market_city_full_display_name;
*/

-- drop view if exists airlines_pg.world_areas_v:
create or replace view airlines_pg.world_areas_v as
SELECT world_area_oai_seq_id, world_area_key
	, world_area_oai_id, effective_from_date, effective_thru_date, world_area_latest_ind
	, world_area_name, world_region_name
	, subdivision_iso_code, subdivision_fips_code, subdivision_name
	, country_iso_code, country_short_name, country_type_descr
	, sovereign_country_name, capital_city_name, world_area_comments_text
FROM air_oai_dims.world_areas;

-- drop view if exists airlines_pg.airline_entity_legacy_groups_v;
create or replace view airlines_pg.airline_entity_legacy_groups_v as
select airline_old_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_legacy_groups
	 
-- drop view if exists airlines_pg.airline_entity_new_groups_v;
create or replace view airlines_pg.airline_entity_new_groups_v as
select airline_new_group_nbr
	, descr
	, long_descr 
from air_oai_dims.airline_entity_new_groups

-- drop view if exists airlines_pg.airline_geographic_types_v;
create or replace view airlines_pg.airline_geographic_types_v as
select geographic_type_oai_id
	, descr
	, long_descr 
from air_oai_dims.airline_geographic_types

-- drop view if exists airlines_pg.airfare_classes_v;
create or replace view airlines_pg.airfare_classes_v as
SELECT airfare_class_code
	, descr
	, long_descr 
FROM air_oai_dims.airfare_classes

-- drop view if exists airlines_pg.airline_traffic_data_sources_v;
create or replace view airlines_pg.airline_traffic_data_sources_v as
SELECT service_class_code
	, descr 
FROM air_oai_dims.airline_traffic_data_sources

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
	, --aircraft_type_brief_name
	, manufacture_year_nbr
	, acquisition_date
	, aircraft_status_code
	, operating_status_ind
	, seats_qty
	, capacity_lbr
from air_oai_fin.airframe_and_engine_inventory_annual

-- drop view if exists airlines_pg.airline_aircraft_by_tail_v;
create or replace view airlines_pg.airline_aircraft_by_tail_v as
select 1 --TODO
--from airline_aircraft_by_tail

