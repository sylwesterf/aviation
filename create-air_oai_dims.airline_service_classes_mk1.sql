-- drop table air_oai_dims.airline_service_classes
create table air_oai_dims.airline_service_classes as
select f.service_class_code
     , max(case when f.service_class_code in ('F','G') then 1 else 0 end::smallint) as scheduled_ind
     , max(case when f.service_class_code in ('L','P') then 1 else 0 end::smallint) as chartered_ind
     , max(case when f.service_class_code = 'F' then 'Scheduled Passenger / Cargo Service'
            when f.service_class_code = 'G' then 'Scheduled CAll Cargo Service'
            when f.service_class_code = 'L' then 'Non-Scheduled Civilian Passenger / Cargo Service'
            when f.service_class_code = 'P' then 'Non-Scheduled Civilian All Cargo Service'
            else null end::varchar(255)) as service_class_descr
     , 'gxclark'::char(32) as created_by
     , now()::timestamp(0) as created_tmst
     , null::char(32) as updated_by
     , null::timestamp(0) as updated_tmst
from air_oai_facts.airline_traffic_market f
group by 1 order by 1;

alter table air_oai_dims.airline_service_classes 
add constraint airline_service_classes_pk primary key (service_class_code);
