-- drop table air_oai_dims.aircraft_configurations
create table air_oai_dims.aircraft_configurations as
select f.aircraft_configuration_ref
     , max(case when f.aircraft_configuration_ref = 'CMB' then 'Combination Freight and Passenger, Main Deck'
            when f.aircraft_configuration_ref = 'FRT' then 'Freight Only, Main Deck'
            when f.aircraft_configuration_ref = 'PAX' then 'Passenger Only, Main Deck'
            when f.aircraft_configuration_ref = 'SEA' then 'Seaplane'
            else null end::varchar(255)) as aircraft_configuration_descr
     , 'gxclark'::char(32) as created_by
     , now()::timestamp(0) as created_tmst
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_segment f
group by 1 order by 1;

alter table air_oai_dims.aircraft_configurations 
add constraint aircraft_configurations_pk primary key (aircraft_configuration_ref);
