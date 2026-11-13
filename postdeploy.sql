----------------------------------------------------
-- STEPS:
-- 1. table maintenance
-- 2. data validation
--  2.1. empty table check
--  2.2. table grain checks
--  2.3. null checks
--  2.4. reference data checks
--  2.5. duplicate record checks
--  2.6. FK reference checks
-- 3. clean-up
----------------------------------------------------

-- 1. table maintenance

-- CAL
ANALYZE calendar_ddb.day_of_week;
ANALYZE calendar_ddb.gregorian_month_of_year;
ANALYZE calendar_ddb.gregorian_quarter_of_year;
ANALYZE calendar_ddb.gregorian_year;
ANALYZE calendar_ddb.gregorian_year_quarter;
ANALYZE calendar_ddb.gregorian_year_month;
ANALYZE calendar_ddb.year_week;
ANALYZE calendar_ddb.calendar_date;
ANALYZE calendar_ddb.calendar_date_hour_min; 
ANALYZE calendar_ddb.calendar_date_hour;
ANALYZE calendar_ddb.cumulative_month_to_dates; 
ANALYZE calendar_ddb.cumulative_quarter_to_dates; 
ANALYZE calendar_ddb.cumulative_year_to_dates;
ANALYZE calendar_ddb.cumulative_week_to_dates;

-- DIM
ANALYZE air_oai_dims.aircraft_types;
ANALYZE air_oai_dims.world_areas;
ANALYZE air_oai_dims.airline_entities;
ANALYZE air_oai_dims.airport_history;
ANALYZE air_oai_dims.aircraft_type_groups;
ANALYZE air_oai_dims.airline_entity_new_groups;
ANALYZE air_oai_dims.airline_entity_legacy_groups;
ANALYZE air_oai_dims.airline_geographic_types;
ANALYZE air_oai_dims.airfare_classes;
ANALYZE air_oai_dims.airline_traffic_data_sources;
ANALYZE air_oai_dims.aircraft_configurations; -- t100 based
ANALYZE air_oai_dims.airline_service_classes; -- t100 based
ANALYZE air_oai_dims.airframe_and_engine_inventory_annual; -- fin based

-- FACTS
ANALYZE air_oai_facts.airline_traffic_market;
ANALYZE air_oai_facts.airline_traffic_segment;
ANALYZE air_oai_facts.airfare_survey_coupon;
ANALYZE air_oai_facts.airfare_survey_itinerary;
ANALYZE air_oai_facts.airfare_survey_market;
ANALYZE air_oai_facts.airline_flights_completed;
ANALYZE air_oai_facts.airline_flights_diverted;
ANALYZE air_oai_facts.airline_flights_diverted_legs;
ANALYZE air_oai_facts.airline_flights_scheduled;

-- 2. data validation
-- 2.1. empty table check
SELECT CASE WHEN count(*) = 0 THEN 'PASSED' 
        ELSE 'FAILED: Empty tables found: ' || string_agg(schema_name || '.' || table_name, ', ') END check_result
FROM duckdb_tables()
WHERE database_name = 'aviation'
  AND schema_name IN ('air_oai_dims', 'air_oai_facts', 'calendar_ddb')
  AND estimated_size = 0;

-- 2.2. table grain checks
-- CAL
select 'CAL' area_tested, 'day_of_week' table_tested, case when count(distinct day_of_week_iso_nbr) = count(*) then 'PASSED' else 'FAILED' end test_result
from calendar_ddb.day_of_week
union all 
select 'CAL', 'gregorian_month_of_year' , case when count(distinct month_of_year_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_month_of_year
union all 
select 'CAL', 'gregorian_quarter_of_year' , case when count(distinct quarter_of_year_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_quarter_of_year
union all 
select 'CAL', 'gregorian_year' , case when count(distinct year_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year
union all 
select 'CAL', 'gregorian_year_quarter' , case when count(distinct year_quarter_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year_quarter
union all 
select 'CAL', 'gregorian_year_month' , case when count(distinct year_month_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year_month
union all 
select 'CAL', 'year_week' , case when count(distinct year_week_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.year_week
union all 
select 'CAL', 'calendar_date' , case when count(distinct calendar_date) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date
union all 
select 'CAL', 'hour_of_day' , case when count(distinct hour_of_day_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.hour_of_day
union all 
select 'CAL', 'minute_of_hour' , case when count(distinct minute_of_hour_nbr) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.minute_of_hour
union all 
select 'CAL', 'calendar_date_hour' , case when count(distinct calendar_timestamp) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date_hour
union all 
select 'CAL', 'calendar_date_hour_min' , case when count(distinct calendar_timestamp) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date_hour_min
union all 
select 'CAL', 'cumulative_month_to_dates' , case when count(*) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_month_to_dates
union all 
select 'CAL', 'cumulative_quarter_to_dates' , case when count(*) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_quarter_to_dates
union all 
select 'CAL', 'cumulative_year_to_dates' , case when count(*) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_year_to_dates
union all 
select 'CAL', 'cumulative_week_to_dates' , case when count(*) = count(*) then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_week_to_dates
union all 

-- DIM
select 'DIM' area_tested, 'aircraft_types' table_tested, case when count(distinct aircraft_type_oai_nbr) = count(*) then 'PASSED' else 'FAILED' end test_result
from air_oai_dims.aircraft_types
union all 
select 'DIM', 'world_areas' , case when count(distinct world_area_oai_seq_id) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.world_areas
union all
select 'DIM', 'airline_entities' , case when count(distinct airline_entity_id) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entities
union all 
select 'DIM', 'airport_history' , case when count(distinct airport_history_id) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airport_history
union all
select 'DIM', 'aircraft_type_groups' , case when count(distinct aircraft_group_oai_nbr) = count(*) then 'PASSED' else 'FAILED' end  
from air_oai_dims.aircraft_type_groups
union all 
select 'DIM', 'airline_entity_new_groups' , case when count(distinct airline_new_group_nbr) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entity_new_groups
union all
select 'DIM', 'airline_entity_legacy_groups' , case when count(distinct airline_old_group_nbr) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entity_legacy_groups 
union all
select 'DIM', 'airline_geographic_types' , case when count(distinct geograhic_type_oai_id) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_geographic_types
union all
select 'DIM', 'airfare_classes' , case when count(distinct airfare_class_code) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airfare_classes
union all
select 'DIM', 'airline_traffic_data_sources' , case when count(distinct service_class_code) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_traffic_data_sources
union all
select 'DIM', 'aircraft_configurations' , case when count(distinct aircraft_configuration_ref) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.aircraft_configurations
union all
select 'DIM', 'airline_service_classes' , case when count(distinct service_class_code) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_service_classes
union all
select 'DIM', 'airframe_and_engine_inventory_annual' , case when count(distinct inventory_key) = count(*) then 'PASSED' else 'FAILED' end
from air_oai_dims.airframe_and_engine_inventory_annual
union all

-- FACTS
select 'FACTS' area_tested, 'airline_flights_completed' table_tested, case when count(*) = count(distinct flight_key) then 'PASSED' else 'FAILED' end test_result
from air_oai_facts.airline_flights_completed
union all 
select 'FACTS', 'airline_flights_diverted' , case when count(*) = count(distinct flight_key) then 'PASSED' else 'FAILED' end
from air_oai_facts.airline_flights_diverted
union all 
select 'FACTS', 'airline_flights_diverted_legs' , case when count(*) = count(distinct (flight_key, diversion_nbr)) then 'PASSED' else 'FAILED' end
from air_oai_facts.airline_flights_diverted_legs
union all 
select 'FACTS', 'airline_flights_scheduled' , case when count(*) = count(distinct flight_key) then 'PASSED' else 'FAILED' end
from air_oai_facts.airline_flights_scheduled
union all 
select 'FACTS', 'airfare_survey_coupon' , case when count(*) = count(distinct (itinerary_oai_id, flight_pass_seq)) then 'PASSED' else 'FAILED' end
from air_oai_facts.airfare_survey_coupon
union all 
select 'FACTS', 'airfare_survey_itinerary' , case when count(*) = count(distinct itinerary_oai_id) then 'PASSED' else 'FAILED' end
from air_oai_facts.airfare_survey_itinerary
union all 
select 'FACTS', 'airfare_survey_market' , case when count(*) = count(distinct (itinerary_oai_id, market_oai_id)) then 'PASSED' else 'FAILED' end
from air_oai_facts.airfare_survey_market
union all 
select 'FACTS', 'airline_traffic_market' , case when count(*) = count(distinct (year_month_nbr, service_class_code, airline_entity_key, depart_airport_history_key, arrive_airport_history_key)) then 'PASSED' else 'FAILED' end
from air_oai_facts.airline_traffic_market
union all 
select 'FACTS', 'airline_traffic_segment' , case when count(*) = count(distinct (year_month_nbr, service_class_code, airline_entity_key, depart_airport_history_key, arrive_airport_history_key, aircraft_type_oai_nbr, aircraft_configuration_ref)) then 'PASSED' else 'FAILED' end
from air_oai_facts.airline_traffic_segment;

-- 2.3. NULL checks
SELECT 'CAL' area_tested, 'day_of_week' table_tested, cast(sum(value IS NULL) / count(*) as decimal(5,2)) as null_to_total_ratio, sum(value IS NULL) AS total_nulls FROM calendar_ddb.day_of_week UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'gregorian_month_of_year' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.gregorian_month_of_year UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'gregorian_quarter_of_year' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.gregorian_quarter_of_year UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'gregorian_year' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.gregorian_year UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'gregorian_year_quarter' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.gregorian_year_quarter UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'gregorian_year_month' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.gregorian_year_month UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'year_week' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.year_week UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'calendar_date' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.calendar_date UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'hour_of_day' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.hour_of_day UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'minute_of_hour' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.minute_of_hour UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'calendar_date_hour' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.calendar_date_hour UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'cumulative_month_to_dates' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.cumulative_month_to_dates UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'cumulative_quarter_to_dates' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.cumulative_quarter_to_dates UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'cumulative_year_to_dates' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.cumulative_year_to_dates UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL
SELECT 'CAL', 'cumulative_week_to_dates' , cast(sum(value IS NULL) / count(*) as decimal(5,2)), sum(value IS NULL) FROM calendar_ddb.cumulative_week_to_dates UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) 
UNION ALL

-- DIMS
select 'DIM' area_tested, 'aircraft_types' table_tested, cast(sum(value IS NULL) / count(*) as decimal(5,2)) as null_to_total_ratio, sum(value IS NULL) AS total_nulls FROM air_oai_dims.aircraft_types UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
union all
SELECT 'DIM', 'world_areas', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.world_areas UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_entities', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_entities UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airport_history', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airport_history UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'aircraft_type_groups', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.aircraft_type_groups UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_entity_new_groups', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_entity_new_groups UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_entity_legacy_groups', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_entity_legacy_groups UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_geographic_types', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_geographic_types UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airfare_classes', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airfare_classes UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_traffic_data_sources', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_traffic_data_sources UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'aircraft_configurations', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.aircraft_configurations UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airline_service_classes', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airline_service_classes UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'DIM', 'airframe_and_engine_inventory_annual', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_dims.airframe_and_engine_inventory_annual UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL

-- FACTS
SELECT 'FACTS' area_tested, 'airline_flights_completed' table_tested, CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)) AS null_to_total_ratio, SUM(value IS NULL) AS total_nulls FROM air_oai_facts.airline_flights_completed UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airline_flights_diverted', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airline_flights_diverted UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airline_flights_diverted_legs', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airline_flights_diverted_legs UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airline_flights_scheduled', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airline_flights_scheduled UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airfare_survey_coupon', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airfare_survey_coupon UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airfare_survey_itinerary', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airfare_survey_itinerary UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airfare_survey_market', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airfare_survey_market UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airline_traffic_market', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airline_traffic_market UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL
UNION ALL
SELECT 'FACTS', 'airline_traffic_segment', CAST(SUM(value IS NULL) / COUNT(*) AS DECIMAL(5,2)), SUM(value IS NULL) FROM air_oai_facts.airline_traffic_segment UNPIVOT INCLUDE NULLS (value FOR name IN (COLUMNS(*)::VARCHAR)) GROUP BY ALL;

-- 2.4. reference data checks
-- CAL
select 'CAL' area_tested, 'day_of_week' table_tested, case when count(distinct day_of_week_iso_nbr) = 7 then 'PASSED' else 'FAILED' end test_result
from calendar_ddb.day_of_week
union all 
select 'CAL', 'gregorian_month_of_year' , case when count(distinct month_of_year_nbr) = 12 then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_month_of_year
union all 
select 'CAL', 'gregorian_quarter_of_year' , case when count(distinct quarter_of_year_nbr) = 4 then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_quarter_of_year
union all 
select 'CAL', 'gregorian_year' , case when count(distinct year_nbr) = 141 then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year
union all 
select 'CAL', 'gregorian_year_quarter' , case when count(distinct year_quarter_nbr) = 564 then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year_quarter
union all 
select 'CAL', 'gregorian_year_month' , case when count(distinct year_month_nbr) = 1692 then 'PASSED' else 'FAILED' end
from calendar_ddb.gregorian_year_month
union all 
select 'CAL', 'year_week' , case when count(distinct year_week_nbr) = 7357 then 'PASSED' else 'FAILED' end
from calendar_ddb.year_week
union all 
select 'CAL', 'calendar_date' , case when count(distinct calendar_date) = 51499 then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date
union all 
select 'CAL', 'hour_of_day' , case when count(distinct hour_of_day_nbr) = 24 then 'PASSED' else 'FAILED' end
from calendar_ddb.hour_of_day
union all 
select 'CAL', 'minute_of_hour' , case when count(distinct minute_of_hour_nbr) = 60 then 'PASSED' else 'FAILED' end
from calendar_ddb.minute_of_hour
union all 
select 'CAL', 'calendar_date_hour' , case when count(distinct calendar_timestamp) = 1235976 then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date_hour
union all 
select 'CAL', 'calendar_date_hour_min' , case when count(distinct calendar_timestamp) = 74158560 then 'PASSED' else 'FAILED' end
from calendar_ddb.calendar_date_hour_min
union all 
select 'CAL', 'cumulative_month_to_dates' , case when count(*) = 814041 then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_month_to_dates
union all 
select 'CAL', 'cumulative_quarter_to_dates' , case when count(*) = 2348301 then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_quarter_to_dates
union all 
select 'CAL', 'cumulative_year_to_dates' , case when count(*) = 9450066 then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_year_to_dates
union all 
select 'CAL', 'cumulative_week_to_dates' , case when count(*) = 205996 then 'PASSED' else 'FAILED' end
from calendar_ddb.cumulative_week_to_dates
union all 

-- DIM
select 'DIM' area_tested, 'aircraft_types' table_tested, case when count(distinct aircraft_type_oai_nbr) = 446 then 'PASSED' else 'FAILED' end test_result
from air_oai_dims.aircraft_types
union all 
select 'DIM', 'world_areas' , case when count(distinct world_area_oai_seq_id) = 344 then 'PASSED' else 'FAILED' end
from air_oai_dims.world_areas
union all
select 'DIM', 'airline_entities' , case when count(distinct airline_entity_id) = 2870 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entities
union all 
select 'DIM', 'airport_history' , case when count(distinct airport_history_id) = 20188 then 'PASSED' else 'FAILED' end
from air_oai_dims.airport_history
union all
select 'DIM', 'aircraft_type_groups' , case when count(distinct aircraft_group_oai_nbr) = 9 then 'PASSED' else 'FAILED' end  
from air_oai_dims.aircraft_type_groups
union all 
select 'DIM', 'airline_entity_new_groups' , case when count(distinct airline_new_group_nbr) = 9 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entity_new_groups
union all
select 'DIM', 'airline_entity_legacy_groups' , case when count(distinct airline_old_group_nbr) = 5 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_entity_legacy_groups 
union all
select 'DIM', 'airline_geographic_types' , case when count(distinct geograhic_type_oai_id) = 3 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_geographic_types
union all
select 'DIM', 'airfare_classes' , case when count(distinct airfare_class_code) = 8 then 'PASSED' else 'FAILED' end
from air_oai_dims.airfare_classes
union all
select 'DIM', 'airline_traffic_data_sources' , case when count(distinct service_class_code) = 4 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_traffic_data_sources
union all
select 'DIM', 'aircraft_configurations' , case when count(distinct aircraft_configuration_ref) = 4 then 'PASSED' else 'FAILED' end
from air_oai_dims.aircraft_configurations
union all
select 'DIM', 'airline_service_classes' , case when count(distinct service_class_code) = 4 then 'PASSED' else 'FAILED' end
from air_oai_dims.airline_service_classes
union all
select 'DIM', 'airframe_and_engine_inventory_annual' , case when count(distinct inventory_key) = 123318 then 'PASSED' else 'FAILED' end
from air_oai_dims.airframe_and_engine_inventory_annual

-- 2.5. duplicate record checks
-- CAL
select 'CAL' area_tested, 'day_of_week' table_tested, case when count(distinct day_of_week_key) = count(*) then 'PASSED' else 'FAILED' end test_result
from calendar_ddb.day_of_week


-- 3. clean-up

-- drop cal_gen schema (views used for generating calendar tables)
DROP SCHEMA cal_gen CASCADE;

-- drop OTP temp table
DROP TABLE IF EXISTS air_oai_facts.airline_flight_performance;



-- 7. validation
-- TODO
select * from air_oai_dims.airline_entities where airline_oai_code = 'DL';

select * from air_oai_dims.airport_history where airport_oai_code = 'NRT'; -- GUID
-- KEY is MD5 Hash of IATA Code + Effective Date.  OAI ~ IATA

select count(*) from air_oai_dims.airport_history; -- 19132
select count(*) from air_oai_dims.airport_history where airport_latest_ind = 1; -- 6644
select count(*) from air_oai_facts.airline_flights_scheduled; -- 7142354



-- 6. Validation
--TODO
select year_nbr, quarter_nbr, count(*) from air_oai_facts.airfare_survey_ticket_fdw group by 1,2;
select year_quarter_start_date, count(*) from air_oai_facts.airfare_survey_itinerary group by 1 order by 1 desc;
-- select itinerary_oai_id, flight_pass_seq, count(*) from airlines_pg.airfare_survey_coupon_v group by 1,2 having count(*) > 1 order by count(*) desc;
-- select market_oai_id, count(*) from airlines_pg.airfare_survey_market_v group by 1 having count(*) > 1 order by count(*) desc;


---------------------------------------------------------
----------------------- fin -----------------------------
---------------------------------------------------------
-- 6. data validation
select count(*) from air_oai_dims.airframe_and_engine_inventory_annual where aircraft_oai_type is null;

select year_nbr, count(*) from air_oai_dims.airframe_and_engine_inventory_annual group by 1 order by 1;
select * from air_oai_dims.airframe_and_engine_inventory_annual limit 25;

---------------------------------------------------------
----------------------- dim -----------------------------
---------------------------------------------------------


-- 13. test/validation queries
-- TODO
-- ROW COUNT


	
-- ### 1
select aircraft_type_oai_nbr, count(*) from air_oai_dims.aircraft_types_fdw group by 1 having count(*) > 1 order by count(*) desc; -- unique! One aircraft one lane




-- ### 2
-- select * from air_oai_dims.wac_country_state_fdw limit 100;
---
--check if it was loaded once, if empty result - good
---	
select world_area_oai_id, effective_from_date, count(*) 
from air_oai_dims.wac_country_state_fdw group by 1,2 having count(*) > 1 order by count(*) desc;

select world_area_oai_seq_id, count(*) 
from air_oai_dims.wac_country_state_fdw group by 1 having count(*) > 1 order by count(*) desc;

select world_area_name, effective_from_date, count(*) 
from air_oai_dims.wac_country_state_fdw group by 1,2 having count(*) > 1 order by count(*) desc;

-- SELECT * FROM air_oai_dims.airline_entities limit 100;
-- select sovereign_country_name, count(*) from air_oai_dims.wac_country_state_fdw group by 1 order by count(*) desc; 

-- select count(*) from air_oai_dims.wac_country_state_fdw; -- 344
-- select count(*) from air_oai_dims.world_areas; -- 344
-- drop foreign table air_oai_dims.wac_country_state_fdw;

-- ### 3
-- select * from air_oai_dims.carrier_decode_fdw;

select airline_usdot_id, count(*) from air_oai_dims.carrier_decode_fdw group by 1 having count(*) > 1 order by count(*) desc;
select airline_oai_code, count(*) from air_oai_dims.carrier_decode_fdw group by 1 having count(*) > 1 order by count(*) desc;
select airline_oai_code, entity_oai_code, count(*) from air_oai_dims.carrier_decode_fdw group by 1,2 having count(*) > 1 order by count(*) desc;

select airline_usdot_id, airline_unique_oai_code, entity_unique_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3,4 having count(*) > 1 order by count(*) desc;

select airline_usdot_id, airline_oai_code, entity_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3,4 having count(*) > 1 order by count(*) desc;

select airline_usdot_id, airline_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3 having count(*) > 1 order by count(*) desc;

select airline_oai_code, entity_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3 having count(*) > 1 order by count(*) desc;

select airline_usdot_id, entity_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3 having count(*) > 1 order by count(*) desc;

select min(airline_usdot_id) as min_id, max(airline_usdot_id) as max_id, count(*) from air_oai_dims.carrier_decode_fdw;

/*
CREATE TABLE color 
( color_id INT GENERATED BY DEFAULT AS IDENTITY (START WITH 10 INCREMENT BY 10)
, color_name VARCHAR NOT NULL);
*/ 

-- WHERE octet_length(col) > length(col);  -- any non-ASCII letter?
-- WHERE col ~ '\W';                       -- anything but digits & letters? 

select airline_oai_code, entity_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw group by 1,2,3 having count(*) > 1 order by count(*) desc;

select count(*) from air_oai_dims.carrier_decode_fdw 
--where airline_usdot_id is null
--where carrier_oai_code is null
--where entity_oai_code is null
--where carrier_name is null
--where unique_carrier_oai_code is null
--where unique_entity_oai_code is null
--where unique_carrier_name is null
--where world_area_oai_code is null
--where carrier_old_group_nbr is null
--where carrier_new_group_nbr is null
--where operating_region_code	is null	
--where source_from_date  is null
where source_thru_date  is null -- yes, many

select airline_oai_code, entity_oai_code, source_from_date, count(*) 
from air_oai_dims.carrier_decode_fdw 
--where ( octet_length(carrier_oai_code) > length(carrier_oai_code) or carrier_oai_code ~ '\W'
--or      octet_length(entity_oai_code) > length(entity_oai_code) or entity_oai_code ~ '\W') 
group by 1,2,3 having count(*) > 1 order by count(*) desc;
-- 3KQ	01267	2021-04-01	2

-- select ctid, * from air_oai_dims.carrier_decode_fdw where airline_oai_code = '3KQ';
-- delete 



 select count(*) from air_oai_dims.airline_entities; -- 2785
select count(*) from air_oai_dims.carrier_decode_fdw; -- 2786
-- drop foreign table if exists air_oai_dims.carrier_decode_fdw;



select ae.airline_entity_id, source_from_date, source_thru_date
     , ae.airline_name, ae.operating_region_code
     , ae.world_area_oai_id, ae.world_area_oai_seq_id
     , wa.world_area_oai_id, wa.world_area_oai_seq_id
     , wa.effective_from_date, wa.effective_thru_date
     , wa.world_area_name
from air_oai_dims.airline_entities ae
left join air_oai_dims.world_areas wa
  on ae.world_area_oai_id = wa.world_area_oai_id
 -- where source_from_date between wa.effective_from_date and coalesce(wa.effective_thru_date, now())
 -- and ae.airline_entity_id in (4542,4545)
;

-- select * from air_oai_dims.world_areas where world_area_oai_id = 10;
-- select * from air_oai_dims.world_areas where country_iso_code = 'US' order by world_area_oai_id;

-- select count(*) from air_oai_dims.airline_entities; -- 2785
-- select count(*) from air_oai_dims.carrier_decode_fdw; -- 2786
-- drop foreign table if exists air_oai_dims.carrier_decode_fdw;



-- select * from air_oai_dims.master_cord_fdw;

select airport_oai_code, airport_effective_from_date, count(*)
from air_oai_dims.master_cord_fdw group by 1,2 having count(*) > 1 order by count(*)  desc; -- unique

select min(airport_oai_id) as min_id, max(airport_oai_id) as max_id, min(airport_oai_seq_id) as min_seq, max(airport_oai_seq_id) as max_seq, count(*)
from air_oai_dims.master_cord_fdw;

select distinct utc_local_time_variation from air_oai_dims.master_cord_fdw;


-- select * from air_oai_dims.airport_history;
select count(*) from air_oai_dims.airport_history; -- 19132
select count(*) from air_oai_dims.master_cord_fdw; -- 19132
-- drop foreign table if exists air_oai_dims.master_cord_fdw;

select case when airport_world_area_oai_id is null then 'null'::char(4) else 'data'::char(4) end as airport_wac_oai_id_data
     , case when airport_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as airport_wac_key_data
     , case when market_city_world_area_oai_id is null then 'null'::char(4) else 'data'::char(4) end as market_city_wac_oai_id_data
     , case when market_city_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as market_city_wac_key_data
     , count(*)
from (
select a.airport_history_id, a.airport_oai_code, a.effective_from_date
     , a.subdivision_iso_code, a.country_iso_code
     , a.airport_world_area_oai_id as airport_wac_oai_id, a.airport_world_area_oai_seq_id as airport_wac_oai_seq_id
     , b.world_area_oai_id as airport_world_area_oai_id, b.world_area_key as airport_world_area_key
     , a.market_city_world_area_oai_id as market_city_wac_oai_id, a.market_city_world_area_oai_seq_id
     , c.world_area_oai_id as market_city_world_area_oai_id, c.world_area_key as market_city_world_area_key
from air_oai_dims.airport_history a 
left outer join air_oai_dims.world_areas b
  on a.airport_world_area_oai_id = b.world_area_oai_id
 and a.airport_world_area_oai_seq_id = b.world_area_oai_seq_id
left outer join air_oai_dims.world_areas c
  on a.market_city_world_area_oai_id = c.world_area_oai_id
 and a.market_city_world_area_oai_seq_id = c.world_area_oai_seq_id
) abc 
group by 1,2,3,4 order by count(*) desc;
--limit 100;

select case when airport_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as airport_wac_key_data
     , case when market_city_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as market_city_wac_key_data
     , count(*)
from air_oai_dims.airport_history
group by 1,2 order by count(*) desc;

/*
select airport_history_id, airport_display_name, airport_oai_code, city_full_display_name, market_city_full_display_name 
from airlines_pg.airport_history_v
where city_full_display_name != market_city_full_display_name;
*/

select country_iso_code
     , max(airport_country_code) as apt_iso 
     , max(market_country_code) as mkt_iso
     , max(airport_world_area_name) as world_area_name
     , max(airport_world_region_name) as world_region_name
     , max(airport_country_type_descr) as country_type_descr
     , max(airport_sovereign_country_name) as sovereign_country_name
     , count(*) as record_qty
from (
select a.airport_history_id, a.airport_history_key
     , a.airport_oai_code, a.effective_from_date
     , a.subdivision_iso_code
     , a.country_iso_code
     , b.country_iso_code as airport_country_code
     , b.country_type_descr as airport_country_type_descr
     , b.sovereign_country_name as airport_sovereign_country_name
     , b.world_area_name as airport_world_area_name
     , b.world_region_name as airport_world_region_name
     , c.country_iso_code as market_country_code
     , c.country_type_descr as market_country_type_descr
     , c.sovereign_country_name as market_sovereign_country_name
     , c.world_area_name as market_world_area_name
     , c.world_region_name as market_world_region_name
from air_oai_dims.airport_history a 
left outer join air_oai_dims.world_areas b
  on a.airport_world_area_key = b.world_area_key
left outer join air_oai_dims.world_areas c
  on a.market_city_world_area_key = c.world_area_key
) x --where country_iso_code != market_country_code
group by 1 order by world_region_name, count(*) desc;

-- 14. clean-up staging tables (foreign table from S3 path or heap table from COPY path)
DROP FOREIGN TABLE IF EXISTS air_oai_dims.aircraft_types_fdw;
DROP TABLE IF EXISTS air_oai_dims.aircraft_types_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_dims.wac_country_state_fdw;
DROP TABLE IF EXISTS air_oai_dims.wac_country_state_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_dims.carrier_decode_fdw;
DROP TABLE IF EXISTS air_oai_dims.carrier_decode_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_dims.master_cord_fdw;
DROP TABLE IF EXISTS air_oai_dims.master_cord_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_dims.f41_schedule_b43_fdw;
DROP TABLE IF EXISTS air_oai_dims.f41_schedule_b43_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_facts.airline_flight_performance_fdw;
DROP TABLE IF EXISTS air_oai_facts.airline_flight_performance_fdw CASCADE;
