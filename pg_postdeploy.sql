-- DATA VALIDATION, CLEAN-UP AND VACUUM GOES HERE

---------------------------------------------------------
----------------------- cal -----------------------------
---------------------------------------------------------
-- 3. Drop cal_gen views (used for generating calendar tables)
drop view if exists cal_gen.make_calendar_date_hour_v;
drop view if exists cal_gen.make_calendar_date_hour_min_v;
drop view if exists cal_gen.make_year_week_v; 
drop view if exists cal_gen.make_calendar_date_v; 
drop view if exists cal_gen.make_gregorian_year_month_v; 
drop view if exists cal_gen.make_gregorian_year_quarter_v; 
drop view if exists cal_gen.make_gregorian_quarter_of_year_v; 
drop view if exists cal_gen.make_day_of_week_v; 
drop view if exists cal_gen.make_gregorian_month_of_year_v; 
drop view if exists cal_gen.make_day_of_month_v; 
drop view if exists cal_gen.make_minute_of_hour_v; 
drop view if exists cal_gen.make_hour_of_day_v; 
drop view if exists cal_gen.make_gregorian_year_v;


---------------------------------------------------------
----------------------- t100 -----------------------------
---------------------------------------------------------
-- 5. vacuum the tables
vacuum analyze air_oai_dims.airline_traffic_market;
vacuum analyze air_oai_dims.airline_traffic_segment;
vacuum analyze air_oai_dims.aircraft_configurations;
vacuum analyze air_oai_dims.airline_service_classes;

-- 6. data validation
-- TODO
select count(*) from air_oai_facts.airline_traffic_market; -- 25544
select count(*) from air_oai_facts.f41_traffic_t100_market_archive; -- 25948

select count(*) from air_oai_facts.airline_traffic_segment; -- 44289
select count(*) from air_oai_facts.f41_traffic_t100_segment_archive; -- 44941

-- 7. clean-up
drop materialized view if exists air_oai_facts.f41_traffic_t100_segment_load_mv;
drop materialized view if exists air_oai_facts.airline_traffic_segment_integrate_mv;
drop materialized view if exists air_oai_facts.airline_traffic_market_integrate_mv;
drop table if exists air_oai_facts.f41_traffic_t100_market_archive;
drop table if exists air_oai_facts.f41_traffic_t100_segment_archive;

---------------------------------------------------------
----------------------- otp -----------------------------
---------------------------------------------------------
-- 6. vacuum
vacuum analyze air_oai_facts.airline_flights_scheduled;
vacuum analyze air_oai_facts.airline_flights_completed;
vacuum analyze air_oai_facts.airline_flights_cancelled;
vacuum analyze air_oai_facts.airline_flights_diverted;
vacuum analyze air_oai_facts.airline_flights_diverted_legs;

-- 7. validation
-- TODO
select * from air_oai_dims.airline_entities where airline_oai_code = 'DL';

select * from air_oai_dims.airport_history where airport_oai_code = 'NRT'; -- GUID
-- KEY is MD5 Hash of IATA Code + Effective Date.  OAI ~ IATA

select count(*) from air_oai_dims.airport_history; -- 19132
select count(*) from air_oai_dims.airport_history where airport_latest_ind = 1; -- 6644
select count(*) from air_oai_facts.airline_flights_scheduled; -- 7142354


-- 8. Clean-up
drop materialized view if exists air_oai_facts.airline_flight_performance_integrated_mv cascade;
drop materialized view if exists air_oai_facts.airline_flight_performance_mv cascade;
drop table if exists air_oai_facts.airline_flight_performance_fdw cascade;

---------------------------------------------------------
----------------------- db1b -----------------------------
---------------------------------------------------------
-- 5. Vacuum on the tables
VACUUM VERBOSE air_oai_facts.airfare_survey_itinerary;
VACUUM VERBOSE air_oai_facts.airfare_survey_coupon;
VACUUM VERBOSE air_oai_facts.airfare_survey_market;

-- 6. Validation
--TODO
select year_nbr, quarter_nbr, count(*) from air_oai_facts.airfare_survey_ticket_load group by 1,2;
select year_quarter_start_date, count(*) from air_oai_facts.airfare_survey_itinerary group by 1 order by 1 desc;
-- select itinerary_oai_id, flight_pass_seq, count(*) from airlines_pg.airfare_survey_coupon_v group by 1,2 having count(*) > 1 order by count(*) desc;
-- select market_oai_id, count(*) from airlines_pg.airfare_survey_market_v group by 1 having count(*) > 1 order by count(*) desc;

-- 7. Clean-up
drop table if exists air_oai_facts.airfare_survey_ticket_load;
drop table if exists air_oai_facts.airfare_survey_coupon_load;
drop table if exists air_oai_facts.airfare_survey_market_load;

---------------------------------------------------------
----------------------- fin -----------------------------
---------------------------------------------------------
-- 6. data validation
select count(*) from air_oai_dims.f41_schedule_b43_fdw where aircraft_type is null; -- 94151 / 29933

select year_nbr, count(*) from air_oai_dims.f41_schedule_b43_fdw group by 1 order by 1;
select * from air_oai_dims.f41_schedule_b43_fdw limit 25;

/* -- verify uniqueness
select * from air_oai_dims.f41_schedule_b43_fdw
where year_nbr::text ||'~'|| carrier_oai_code ||'~'|| tail_nbr /*||'~'|| serial_nbr*/ in
(select year_nbr::text ||'~'|| carrier_oai_code ||'~'|| tail_nbr /*||'~'|| serial_nbr*/
from air_oai_dims.f41_schedule_b43_fdw group by 1 having count(*) > 1)
order by year_nbr, carrier_oai_code, tail_nbr;
*/

-- 7. clean-up
drop table if exists air_oai_dims.f41_schedule_b43_fdw

---------------------------------------------------------
----------------------- dim -----------------------------
---------------------------------------------------------
-- 12. vacuum the tables
vacuum analyze air_oai_dims.aircraft_types;
vacuum analyze air_oai_dims.world_areas;
vacuum analyze air_oai_dims.airport_history;
vacuum analyze air_oai_dims.aircraft_type_groups;
vacuum analyze air_oai_dims.airline_entity_new_groups;
vacuum analyze air_oai_dims.airline_entity_legacy_groups;
vacuum analyze air_oai_dims.airline_entities


-- 13. test/validation queries
-- TODO
-- ROW COUNT

select 'aircraft_types' area_tested, case when count(distinct aircraft_type_oai_nbr) = 437 then 'passed' else 'error' end test_result
from air_oai_dims.aircraft_types
union all 
select 'world_areas', case when count(distinct world_area_oai_seq_id) = 344 then 'passed' else 'error' end
from air_oai_dims.world_areas
union all 
select 'airport_history', case when count(distinct airport_history_id) = 19150 then 'passed' else 'error' end
from air_oai_dims.airport_history
union all
--in Geof script is 10
-- changed aircraft_configuration_ref for  aircraft_group_oai_nbr
select 'aircraft_type_groups', case when count(distinct aircraft_group_oai_nbr) = 9 then 'passed' else 'error' end  
from air_oai_dims.aircraft_type_groups
union all 
--changed airline_entity_id for airline_new_group_nbr
select 'airline_entity_new_groups', case when count(distinct airline_new_group_nbr) = 9 then 'passed' else 'error' end
from air_oai_dims.airline_entity_new_groups
union all
--changed airline_entity_id for airline_old_group_nbr
select 'airline_entity_legacy_groups', case when count(distinct airline_old_group_nbr) = 5 then 'passed' else 'error' end
from air_oai_dims.airline_entity_legacy_groups 
union all
select 'airline_entities', case when count(distinct airline_entity_id) = 2791 then 'passed' else 'error' end
from air_oai_dims.airline_entities

	
-- ### 1
select aircraft_type_oai_nbr, count(*) from air_oai_dims.aircraft_types_fdw group by 1 having count(*) > 1 order by count(*) desc; -- unique! One aircraft one lane

select * from air_oai_dims.aircraft_types; 
select * from air_oai_dims.aircraft_types_fdw; -- 433
drop foreign table if exists air_oai_dims.aircraft_types_fdw;


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

-- 14. clean-up fdw/landing tables
DROP TABLE IF EXISTS air_oai_dims.aircraft_types_fdw;
DROP TABLE IF EXISTS air_oai_dims.wac_country_state_fdw;
DROP TABLE IF EXISTS air_oai_dims.carrier_decode_fdw;
DROP TABLE IF EXISTS air_oai_dims.master_cord_fdw;
