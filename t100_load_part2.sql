-- merge w/ t100_load.sql

-- air_oai_dims.aircraft_configurations
drop table if exists air_oai_dims.aircraft_configurations;
create table air_oai_dims.aircraft_configurations as
select f.aircraft_configuration_ref
     , max(case when f.aircraft_configuration_ref = 'CMB' then 'Combination Freight and Passenger, Main Deck'
            when f.aircraft_configuration_ref = 'FRT' then 'Freight Only, Main Deck'
            when f.aircraft_configuration_ref = 'PAX' then 'Passenger Only, Main Deck'
            when f.aircraft_configuration_ref = 'SEA' then 'Seaplane'
            else null end::varchar(255)) as aircraft_configuration_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_segment f
group by 1 order by 1;

alter table air_oai_dims.aircraft_configurations 
add constraint aircraft_configurations_pk primary key (aircraft_configuration_ref);

-- air_oai_dims.airline_service_classes
drop table if exists air_oai_dims.airline_service_classes;
create table air_oai_dims.airline_service_classes as
select f.service_class_code
     , max(case when f.service_class_code in ('F','G') then 1 else 0 end::smallint) as scheduled_ind
     , max(case when f.service_class_code in ('L','P') then 1 else 0 end::smallint) as chartered_ind
     , max(case when f.service_class_code = 'F' then 'Scheduled Passenger / Cargo Service'
            when f.service_class_code = 'G' then 'Scheduled CAll Cargo Service'
            when f.service_class_code = 'L' then 'Non-Scheduled Civilian Passenger / Cargo Service'
            when f.service_class_code = 'P' then 'Non-Scheduled Civilian All Cargo Service'
            else null end::varchar(255)) as service_class_descr
     , current_user::varchar(32) as created_by
     , current_timestamp::timestamp(0) as created_ts
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_market f
group by 1 order by 1;

alter table air_oai_dims.airline_service_classes 
add constraint airline_service_classes_pk primary key (service_class_code);
