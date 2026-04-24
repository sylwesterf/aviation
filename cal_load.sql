-- Create date dimension tables

----------------------------------------------------
-- STEPS:
-- 1. Create cal_gen views that generate information about all date/time parts
-- 2. Create calendar tables based on base views and start/end year
----------------------------------------------------

-- 1. Create cal_gen views that generate information about all date/time parts
-- cal_gen.make_gregorian_year_v;
-------------------------------------------------------------------
-- schema preparation (Redshift)
-------------------------------------------------------------------
create schema cal_gen;
create schema calendar_pg;

-------------------------------------------------------------------
-- 1. VIEWS IN cal_gen
-------------------------------------------------------------------

-- cal_gen.make_gregorian_year_v
-- Create a number table
create temp table numbers_0_3000 as
select row_number() over (order by true) - 1 as n
from svv_tables          
limit 3001;    

create or replace view cal_gen.make_gregorian_year_v as
select
    year_nbr::smallint                                               as year_nbr,
    lpad(year_nbr::varchar, 4, '0')::char(4)                         as year_code,
    case
        when mod(year_nbr, 400) = 0 then 1
        when mod(year_nbr, 100) = 0 then 0
        when mod(year_nbr, 4)   = 0 then 1
        else 0
    end::smallint                                                    as leap_year_ind,
    (lpad(year_nbr::varchar, 4, '0') || '-01-01')::date              as year_from_date,
    (lpad(year_nbr::varchar, 4, '0') || '-12-31')::date              as year_thru_date,
    (lpad(year_nbr::varchar, 4, '0') || '-12-31')::date
      - (lpad(year_nbr::varchar, 4, '0') || '-01-01')::date          as day_qty,
    lag(year_nbr, 1) over (order by year_nbr)                        as last_year_nbr
from (
    select n as year_nbr
    from numbers_0_3000
) y
where year_nbr between 1000 and 3000
order by year_code;    




-- cal_gen.make_hour_of_day_v
create or replace view cal_gen.make_hour_of_day_v as
with hours as (
    select (row_number() over (order by true) - 1) as hour_of_day_nbr
    from svv_tables
    limit 24
)
select
    h.hour_of_day_nbr::integer                                   as hour_of_day_nbr,
    lpad(h.hour_of_day_nbr::varchar, 2, '0')::char(2)            as hour_of_day_code,
    (lpad(h.hour_of_day_nbr::varchar, 2, '0') || ':00')::time    as hour_of_day_time,
    case
        when h.hour_of_day_nbr between  0 and 11 then 'am'
        else 'pm'
    end::char(2)                                                 as period_code
from hours h
order by hour_of_day_nbr;


-- cal_gen.make_minute_of_hour_v
create or replace view cal_gen.make_minute_of_hour_v as
select cast(v1.column1::char(1) || v2.column1::char(1) as char(2)) as minute_of_hour_code
     , cast(v1.column1::char(1) || v2.column1::char(1) as smallint) as minute_of_hour_nbr
from       (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) v1
cross join (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) v2
where cast(v1.column1::char(1) || v2.column1::char(1) as smallint) < 60
order by 1,2;

-- cal_gen.make_day_of_month_v
create or replace view cal_gen.make_day_of_month_v as
select cast(v1.column1::char(1) || v2.column1::char(1) as smallint) as day_of_month_nbr
     , cast(v1.column1::char(1) || v2.column1::char(1) as char(2)) as day_of_month_code
from       (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) v1
cross join (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) v2
where cast(v1.column1::char(1) || v2.column1::char(1) as smallint) between 1 and 35
order by 1,2;

-- cal_gen.make_gregorian_month_of_year_v
create or replace view cal_gen.make_gregorian_month_of_year_v as
select column1::smallint as month_of_year_nbr
     , column2::char(2) as month_of_year_code
     , column3::smallint as quarter_of_year_nbr
     , column4::smallint as standard_year_day_qty
     , column5::smallint as leap_year_day_qty
     , column6::char(3) as month_of_year_abbr
     , column7::varchar(10) as month_of_year_name
from (
values 
  ( 1,'01','1','31','31','Jan','Janurary')
, ( 2,'02','1','28','29','Feb','February')
, ( 3,'03','1','31','31','Mar','March')
, ( 4,'04','2','30','30','Apr','April')
, ( 5,'05','2','31','31','May','May')
, ( 6,'06','2','30','30','Jun','June')
, ( 7,'07','3','31','31','Jul','July')
, ( 8,'08','3','31','31','Aug','August')
, ( 9,'09','3','30','30','Sep','September')
, (10,'10','4','31','31','Oct','October')
, (11,'11','4','30','30','Nov','November')
, (12,'12','4','31','31','Dec','December')
) mo;

-- cal_gen.make_day_of_week_v
create or replace view cal_gen.make_day_of_week_v as
select column2::smallint as day_of_week_iso_nbr
     , column1::smallint as day_of_week_common_nbr
     , column3::smallint as day_of_week_pgsql_nbr
     , column4::char(3) as day_of_week_abbr
     , column5::varchar(10) as day_of_week_name_eng
from (
values
  (1,7,0,'Sun','Sunday')
, (2,1,1,'Mon','Monday')
, (3,2,2,'Tue','Tuesday')
, (4,3,3,'Wed','Wednesday')
, (5,4,4,'Thu','Thursday')
, (6,5,5,'Fri','Friday')
, (7,6,6,'Sat','Saturday')
) dow
order by 1;

-- cal_gen.make_gregorian_quarter_of_year_v
create or replace view cal_gen.make_gregorian_quarter_of_year_v as
select column1::smallint as quarter_of_year_nbr
     , column2::char(1) as quarter_of_year_code
     , column3::char(2) as quarter_of_year_abbr
     , column4::varchar(15) as quarter_of_year_name
from (
values
  (1,'1','Q1','First Quarter')
, (2,'2','Q2','Second Quarter')
, (3,'3','Q3','Third Quarter')
, (4,'4','Q4','Fourth Quarter')
) qoy;

-- cal_gen.make_gregorian_year_quarter_v
create or replace view cal_gen.make_gregorian_year_quarter_v as
select year_quarter_nbr::integer as year_quarter_nbr
     , year_quarter_standard_code::char(7) as year_quarter_standard_code
     , year_nbr::smallint as year_nbr
     , quarter_of_year_nbr::smallint as quarter_of_year_nbr
     , year_quarter_from_date::date as year_quarter_from_date
     , year_quarter_thru_date::date as year_quarter_thru_date
     , lag(year_quarter_nbr,1) over (order by year_quarter_nbr) as last_year_quarter_nbr
     , lag(year_quarter_nbr,4) over (order by year_quarter_nbr) as last_year_this_quarter_nbr
from (
    select (y.year_code || q.quarter_of_year_code)::integer year_quarter_nbr
         , y.year_code || '-' || q.quarter_of_year_abbr::char(7) as year_quarter_standard_code
         , y.year_nbr::smallint as year_nbr
         , q.quarter_of_year_nbr::smallint as quarter_of_year_nbr
         , (y.year_code ||
              case when q.quarter_of_year_nbr = 1 then '-01-01' 
                   when q.quarter_of_year_nbr = 2 then '-04-01'
                   when q.quarter_of_year_nbr = 3 then '-07-01'
                   when q.quarter_of_year_nbr = 4 then '-10-01'
                   else null end)::date as year_quarter_from_date
         , (y.year_code ||
              case when q.quarter_of_year_nbr = 1 then '-03-31' 
                   when q.quarter_of_year_nbr = 2 then '-06-30'
                   when q.quarter_of_year_nbr = 3 then '-09-30'
                   when q.quarter_of_year_nbr = 4 then '-12-31'
                   else null end)::date as year_quarter_thru_date
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_quarter_of_year_v q
    where y.year_nbr between 1000 and 3000
) yq
order by 1;

-- cal_gen.make_gregorian_year_month_v
create or replace view cal_gen.make_gregorian_year_month_v as
select year_month_nbr::integer as year_month_nbr
     , year_month_standard_code::char(7) as year_month_standard_code
     , month_of_year_nbr::smallint as month_of_year_nbr
     , year_quarter_nbr::integer as year_quarter_nbr
     , year_nbr::smallint as year_nbr
     , year_month_from_date::date as year_month_from_date
     , year_month_thru_date::date as year_month_thru_date
     , lag(year_month_nbr,1) over (order by year_month_nbr) as last_year_month_nbr
     , lag(year_month_nbr,3) over (order by year_month_nbr) as last_quarter_this_month_nbr
     , lag(year_month_nbr,12) over (order by year_month_nbr) as last_year_this_month_nbr
from (
    select (y.year_code || m.month_of_year_code)::integer year_month_nbr
         , y.year_code || '-' || m.month_of_year_code::char(7) as year_month_standard_code
         , m.month_of_year_nbr
         , (y.year_code || m.quarter_of_year_nbr::char(1))::integer as year_quarter_nbr
         , y.year_nbr
         , (y.year_code || '-' || m.month_of_year_code || '-01')::date as year_month_from_date
         , (y.year_code || '-' || m.month_of_year_code || '-'
            || case when y.leap_year_ind = 1 then leap_year_day_qty
                    when y.leap_year_ind = 0 then standard_year_day_qty
                    else '01' end)::date as year_month_thru_date
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v m
    where y.year_nbr between 1000 and 3000
) ym
order by 1;

-- cal_gen.make_calendar_date_v
create or replace view cal_gen.make_calendar_date_v as 
select dt.calendar_date
     , extract(isodow from dt.calendar_date)::smallint as day_of_week_iso_nbr
     , extract(week from dt.calendar_date)::smallint as week_of_year_nbr
     , (extract(isoyear from dt.calendar_date)::char(4)
        || case when len(extract(week from dt.calendar_date)::varchar(2)) < 2 
                then '0' || extract(week from dt.calendar_date)::char(1)
                else extract(week from dt.calendar_date)::char(2)
           end)::integer as year_week_nbr
     , m.year_month_nbr::integer as year_month_nbr
     , m.year_quarter_nbr::integer as year_quarter_nbr
     , dt.year_nbr::smallint as year_nbr
     , lag(dt.calendar_date, 1) over (order by dt.calendar_date) as yesterday_date
     , (calendar_date - interval '1 week')::date as this_day_last_week
     , (calendar_date - interval '1 month')::date as this_day_last_month
     , (calendar_date - interval '3 months')::date as this_day_last_quarter
     , (calendar_date - interval '1 year')::date as this_day_last_year
from (
    select (y.year_code || '-' || moy.month_of_year_code || '-' || dom.day_of_month_code)::date as calendar_date
         , y.year_nbr
         , y.leap_year_ind
         , moy.month_of_year_nbr
         , moy.standard_year_day_qty::integer as standard_year_day_qty
         , moy.leap_year_day_qty::integer as leap_year_day_qty
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v moy
    cross join cal_gen.make_day_of_month_v dom
    where dom.day_of_month_nbr <= (case when y.leap_year_ind = 1 then leap_year_day_qty else standard_year_day_qty end::integer)
      and y.year_nbr between 1000 and 3000 
) dt
left join cal_gen.make_gregorian_year_month_v m
  on dt.year_nbr = m.year_nbr
 and dt.month_of_year_nbr = m.month_of_year_nbr
order by 1;

-- cal_gen.make_year_week_v
create or replace view cal_gen.make_year_week_v as
select year_week_nbr
     , max(week_of_year_nbr) as week_of_year_nbr
     , max(substring(year_week_nbr::varchar(6),1,4))::smallint as year_nbr
     , max(year_nbr::varchar(4) || '-W' || substring((year_week_nbr::char(6)),5,2))::char(8) as year_week_std_cd
     , min(calendar_date) as week_from_dt
     , max(calendar_date) as week_thru_dt
from cal_gen.make_calendar_date_v
where year_nbr between 1000 and 3000
group by 1
order by 1;

-- cal_gen.make_calendar_date_hour_min_v
create or replace view cal_gen.make_calendar_date_hour_min_v as
select (
        (d.calendar_date::char(10)::text || ' ' || h.hour_of_day_code || ':' || m.minute_of_hour_code || ':00')
       )::timestamp as calendar_timestamp,
       d.calendar_date,
       h.hour_of_day_nbr,
       h.hour_of_day_code,
       h.hour_of_day_time,
       h.period_code,
       m.minute_of_hour_nbr,
       m.minute_of_hour_code
from cal_gen.make_calendar_date_v d
join cal_gen.make_hour_of_day_v h on 1=1
join cal_gen.make_minute_of_hour_v m on 1=1
order by d.calendar_date, h.hour_of_day_nbr, m.minute_of_hour_nbr;

-- cal_gen.make_calendar_date_hour_v
create or replace view cal_gen.make_calendar_date_hour_v as
select (
        d.calendar_date::char(10)::text || ' ' || h.hour_of_day_time::char(8)::text
       )::timestamp as calendar_timestamp,
       d.calendar_date,
       h.hour_of_day_nbr,
       h.hour_of_day_code,
       h.hour_of_day_time,
       h.period_code
from cal_gen.make_calendar_date_v d
join cal_gen.make_hour_of_day_v h on 1=1
order by d.calendar_date, h.hour_of_day_nbr;

-------------------------------------------------------------------
-- 2. CALENDAR TABLES IN calendar_pg (1900–2090)
-------------------------------------------------------------------

create table if not exists calendar_pg.day_of_week as
select * from cal_gen.make_day_of_week_v;

create table if not exists calendar_pg.gregorian_month_of_year as
select * from cal_gen.make_gregorian_month_of_year_v;

create table if not exists calendar_pg.gregorian_quarter_of_year as
select * from cal_gen.make_gregorian_quarter_of_year_v;

create table if not exists calendar_pg.gregorian_year as
select * 
from cal_gen.make_gregorian_year_v
where year_nbr between 1900 and 2090;

create table if not exists calendar_pg.gregorian_year_quarter as
select * 
from cal_gen.make_gregorian_year_quarter_v
where year_nbr between 1900 and 2090;

create table if not exists calendar_pg.gregorian_year_month as
select * 
from cal_gen.make_gregorian_year_month_v
where year_nbr between 1900 and 2090;

create table if not exists calendar_pg.year_week as
select * 
from cal_gen.make_year_week_v
where year_nbr between 1900 and 2090;

create table if not exists calendar_pg.calendar_date as
select * 
from cal_gen.make_calendar_date_v
where year_nbr between 1900 and 2090;

create table if not exists calendar_pg.hour_of_day as
select * from cal_gen.make_hour_of_day_v;

create table if not exists calendar_pg.minute_of_hour as
select * from cal_gen.make_minute_of_hour_v;

create table if not exists calendar_pg.calendar_date_hour_min as
select * 
from cal_gen.make_calendar_date_hour_min_v
where date_part(year, calendar_date) between 1900 and 2090;

create table if not exists calendar_pg.calendar_date_hour as
select * 
from cal_gen.make_calendar_date_hour_v
where date_part(year, calendar_date) between 1900 and 2090;

-------------------------------------------------------------------
-- 3. PRIMARY KEYS AND INDEX 
-------------------------------------------------------------------

-- PRIMARY KEYS
alter table calendar_pg.day_of_week
  add constraint day_of_week_pk primary key (day_of_week_iso_nbr);

alter table calendar_pg.gregorian_month_of_year
  add constraint gregorian_month_of_year_pk primary key (month_of_year_nbr);

alter table calendar_pg.gregorian_quarter_of_year
  add constraint gregorian_quarter_of_year_pk primary key (quarter_of_year_nbr);

alter table calendar_pg.gregorian_year
  add constraint gregorian_year_pk primary key (year_nbr);

alter table calendar_pg.gregorian_year_quarter
  add constraint gregorian_year_quarter_pk primary key (year_quarter_nbr);

alter table calendar_pg.gregorian_year_month
  add constraint gregorian_year_month_pk primary key (year_month_nbr);

alter table calendar_pg.year_week
  add constraint year_week_pk primary key (year_week_nbr);

alter table calendar_pg.calendar_date
  add constraint calendar_date_pk primary key (calendar_date);

alter table calendar_pg.hour_of_day
  add constraint hour_of_day_pk primary key (hour_of_day_nbr);

alter table calendar_pg.minute_of_hour
  add constraint minute_of_hour_pk primary key (minute_of_hour_nbr);

-- ÍNDICES (declarativos; en Redshift son lógicos)
create unique index if not exists gregorian_month_of_year_ak1
  on calendar_pg.gregorian_month_of_year (month_of_year_code);

create unique index if not exists gregorian_year_quarter_ak1
  on calendar_pg.gregorian_year_quarter (year_quarter_standard_code);

create unique index if not exists year_week_ak1
  on calendar_pg.year_week (year_nbr, week_of_year_nbr);

create index if not exists calendar_date_year_week_if1
  on calendar_pg.calendar_date (year_week_nbr);

create index if not exists calendar_date_year_month_if2
  on calendar_pg.calendar_date (year_month_nbr);

create index if not exists calendar_date_day_of_week_if3
  on calendar_pg.calendar_date (day_of_week_iso_nbr);

create index if not exists gregorian_month_of_year_quarter_of_year_if1
  on calendar_pg.gregorian_month_of_year (quarter_of_year_nbr);

create index if not exists gregorian_year_month_year_quarter_if1
  on calendar_pg.gregorian_year_month (year_quarter_nbr);

create index if not exists gregorian_year_month_of_year_if1
  on calendar_pg.gregorian_year_month (month_of_year_nbr);

create index if not exists gregorian_year_quarter_year_if1
  on calendar_pg.gregorian_year_quarter (year_nbr);

create index if not exists gregorian_year_quarter_of_year_if2
  on calendar_pg.gregorian_year_quarter (quarter_of_year_nbr);

create index if not exists year_week_if1
  on calendar_pg.year_week (year_nbr);

-------------------------------------------------------------------
-- 4. FOREIGN KEYS 
-------------------------------------------------------------------

alter table calendar_pg.calendar_date
  add constraint calendar_date_year_week_fk
  foreign key (year_week_nbr) references calendar_pg.year_week (year_week_nbr);

alter table calendar_pg.calendar_date
  add constraint calendar_date_year_month_fk
  foreign key (year_month_nbr) references calendar_pg.gregorian_year_month (year_month_nbr);

alter table calendar_pg.calendar_date
  add constraint calendar_date_day_of_week_fk
  foreign key (day_of_week_iso_nbr) references calendar_pg.day_of_week (day_of_week_iso_nbr);

alter table calendar_pg.gregorian_month_of_year
  add constraint gregorian_month_of_year_quarter_of_year_fk
  foreign key (quarter_of_year_nbr) references calendar_pg.gregorian_quarter_of_year (quarter_of_year_nbr);

alter table calendar_pg.gregorian_year_month
  add constraint gregorian_year_month_year_quarter_fk
  foreign key (year_quarter_nbr) references calendar_pg.gregorian_year_quarter (year_quarter_nbr);

alter table calendar_pg.gregorian_year_month
  add constraint gregorian_year_month_month_of_year_fk
  foreign key (month_of_year_nbr) references calendar_pg.gregorian_month_of_year (month_of_year_nbr);

alter table calendar_pg.gregorian_year_quarter
  add constraint gregorian_year_quarter_year_fk
  foreign key (year_nbr) references calendar_pg.gregorian_year (year_nbr);

alter table calendar_pg.gregorian_year_quarter
  add constraint gregorian_year_quarter_quarter_of_year_fk
  foreign key (quarter_of_year_nbr) references calendar_pg.gregorian_quarter_of_year (quarter_of_year_nbr);

alter table calendar_pg.year_week
  add constraint year_week_gregorian_year_fk
  foreign key (year_nbr) references calendar_pg.gregorian_year (year_nbr);

alter table calendar_pg.calendar_date_hour_min
  add constraint calendar_date_hour_min_calendar_date_fk
  foreign key (calendar_date) references calendar_pg.calendar_date (calendar_date);

alter table calendar_pg.calendar_date_hour
  add constraint calendar_date_hour_calendar_date_fk
  foreign key (calendar_date) references calendar_pg.calendar_date (calendar_date);

-------------------------------------------------------------------
-- 5. Tables(MTD, QTD, YTD, WTD)
-------------------------------------------------------------------

-- MTD
create table if not exists calendar_pg.cumulative_month_to_dates as
select d.calendar_date, x.calendar_date as cumulative_month_to_date
from calendar_pg.calendar_date d
join calendar_pg.calendar_date x 
  on d.year_month_nbr = x.year_month_nbr
where x.calendar_date <= d.calendar_date
  and x.calendar_date <= (select max(calendar_date) from calendar_pg.calendar_date)
order by d.calendar_date, x.calendar_date;

-- QTD
create table if not exists calendar_pg.cumulative_quarter_to_dates as
select d.calendar_date, x.calendar_date as cumulative_quarter_to_date
from calendar_pg.calendar_date d
join calendar_pg.calendar_date x 
  on d.year_quarter_nbr = x.year_quarter_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- YTD
create table if not exists calendar_pg.cumulative_year_to_dates as
select d.calendar_date, x.calendar_date as cumulative_year_to_date
from calendar_pg.calendar_date d
join calendar_pg.calendar_date x 
  on d.year_nbr = x.year_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- WTD
create table if not exists calendar_pg.cumulative_week_to_dates as
select d.calendar_date, x.calendar_date as cumulative_week_to_date
from calendar_pg.calendar_date d
join calendar_pg.calendar_date x 
  on d.year_week_nbr = x.year_week_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- PK/FK 

-- QTD
alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_pk
  primary key (calendar_date, cumulative_quarter_to_date);

alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_base_date_fk
  foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);

alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_qtd_date_fk
  foreign key (cumulative_quarter_to_date)
  references calendar_pg.calendar_date (calendar_date);

-- YTD
alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_pk
  primary key (calendar_date, cumulative_year_to_date);

alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_base_date_fk
  foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);

alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_qtd_date_fk
  foreign key (cumulative_year_to_date)
  references calendar_pg.calendar_date (calendar_date);

-- WTD
alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_pk
  primary key (calendar_date, cumulative_week_to_date);

alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_base_date_fk
  foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);

alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_qtd_date_fk
  foreign key (cumulative_week_to_date)
  references calendar_pg.calendar_date (calendar_date);

-------------------------------------------------------------------
-- 6. Views calendar_pg
-------------------------------------------------------------------

create or replace view calendar_pg.day_of_week_v as
select *, 1::integer as day_of_week_qty
from calendar_pg.day_of_week;

create or replace view calendar_pg.month_of_year_v as
select *, 1::integer as month_of_year_qty
from calendar_pg.gregorian_month_of_year;

create or replace view calendar_pg.quarter_of_year_v as
select *, 1::integer as quarter_of_year_qty
from calendar_pg.gregorian_quarter_of_year;

create or replace view calendar_pg.calendar_year_v as
select *, 1::integer as calendar_year_qty
from calendar_pg.gregorian_year;

create or replace view calendar_pg.year_quarter_v as
select *, 1::integer as year_quarter_qty
from calendar_pg.gregorian_year_quarter;

create or replace view calendar_pg.year_month_v as
select *, 1::integer as year_month_qty
from calendar_pg.gregorian_year_month;

create or replace view calendar_pg.year_week_v as
select *, 1::integer as year_week_qty
from calendar_pg.year_week;

create or replace view calendar_pg.calendar_date_v as
select *, 1::integer as calendar_date_qty
from calendar_pg.calendar_date;

create or replace view calendar_pg.calendar_date_hour_min_v as
select *, 1::integer as calendar_date_hour_min_qty
from calendar_pg.calendar_date_hour_min;

create or replace view calendar_pg.calendar_date_hour_v as
select *, 1::integer as calendar_date_hour_qty
from calendar_pg.calendar_date_hour;

create or replace view calendar_pg.cumulative_month_to_dates_v as
select calendar_date, cumulative_month_to_date
from calendar_pg.cumulative_month_to_dates;

create or replace view calendar_pg.cumulative_quarter_to_dates_v as
select calendar_date, cumulative_quarter_to_date
from calendar_pg.cumulative_quarter_to_dates;

create or replace view calendar_pg.cumulative_year_to_dates_v as
select calendar_date, cumulative_year_to_date
from calendar_pg.cumulative_year_to_dates;

create or replace view calendar_pg.cumulative_week_to_dates_v as
select calendar_date, cumulative_week_to_date
from calendar_pg.cumulative_week_to_dates;