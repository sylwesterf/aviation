-- Create date dimension tables

----------------------------------------------------
-- STEPS:
-- 1. Create cal_gen views that generate information about all date/time parts
-- 2. Create calendar tables based on base views and start/end year
----------------------------------------------------

-- 1. Create cal_gen views that generate information about all date/time parts
-- cal_gen.make_gregorian_year_v;
create or replace view cal_gen.make_gregorian_year_v as
select 
      y.year_nbr::smallint as year_nbr
    , y.year_nbr::varchar::char(4) as year_code
    , case when mod(y.year_nbr, 400) = 0 then 1
           when mod(y.year_nbr, 100) = 0 then 0
           when mod(y.year_nbr, 4) = 0 then 1
           else 0 end::smallint as leap_year_ind
    , (y.year_nbr::varchar || '-01-01')::date as year_from_date
    , (y.year_nbr::varchar || '-12-31')::date as year_thru_date
    , ((y.year_nbr::varchar || '-12-31')::date - (y.year_nbr::varchar || '-01-01')::date) + 1 as day_qty
    , lag(y.year_nbr, 1) over (order by y.year_nbr) as last_year_nbr
from (
    select range::smallint as year_nbr 
    from range(1000, 3001)
) y;

-- cal_gen.make_hour_of_day_v;
create or replace view cal_gen.make_hour_of_day_v as
select 
      col0::integer as hour_of_day_nbr
    , col1::char(2) as hour_of_day_code
    , (col1 || ':00')::time as hour_of_day_time
    , col2::char(2) as period_code
from (values 
     (0,'00','am'),(1,'01','am'),(2,'02','am'),(3,'03','am'),(4,'04','am'),(5,'05','am'),
     (6,'06','am'),(7,'07','am'),(8,'08','am'),(9,'09','am'),(10,'10','am'),(11,'11','am'),
     (12,'12','pm'),(13,'13','pm'),(14,'14','pm'),(15,'15','pm'),(16,'16','pm'),(17,'17','pm'),
     (18,'18','pm'),(19,'19','pm'),(20,'20','pm'),(21,'21','pm'),(22,'22','pm'),(23,'23','pm')
) hod;
-- cal_gen.make_minute_of_hour_v;
create or replace view cal_gen.make_minute_of_hour_v as
select 
      lpad(range::varchar, 2, '0')::char(2) as minute_of_hour_code
    , range::smallint as minute_of_hour_nbr
from range(0, 60);

-- cal_gen.make_day_of_month_v;
create or replace view cal_gen.make_day_of_month_v as
select 
      range::smallint as day_of_month_nbr
    , lpad(range::varchar, 2, '0')::char(2) as day_of_month_code
from range(1, 32);

-- cal_gen.make_gregorian_month_of_year_v;
create or replace view cal_gen.make_gregorian_month_of_year_v as
select 
      col0::smallint as month_of_year_nbr
    , col1::char(2) as month_of_year_code
    , col2::smallint as quarter_of_year_nbr
    , col3::smallint as standard_year_day_qty
    , col4::smallint as leap_year_day_qty
    , col5::char(3) as month_of_year_abbr
    , col6::varchar as month_of_year_name
from (values 
  (1,'01',1,31,31,'Jan','January'),
  (2,'02',1,28,29,'Feb','February'),
  (3,'03',1,31,31,'Mar','March'),
  (4,'04',2,30,30,'Apr','April'),
  (5,'05',2,31,31,'May','May'),
  (6,'06',2,30,30,'Jun','June'),
  (7,'07',3,31,31,'Jul','July'),
  (8,'08',3,31,31,'Aug','August'),
  (9,'09',3,30,30,'Sep','September'),
  (10,'10',4,31,31,'Oct','October'),
  (11,'11',4,30,30,'Nov','November'),
  (12,'12',4,31,31,'Dec','December')
) mo;

-- cal_gen.make_day_of_week_v;
create or replace view cal_gen.make_day_of_week_v as
select 
      col1::smallint as day_of_week_iso_nbr
    , col0::smallint as day_of_week_common_nbr
    , col2::smallint as day_of_week_pgsql_nbr
    , col3::char(3) as day_of_week_abbr
    , col4::varchar as day_of_week_name_eng
from (values
  (1,7,0,'Sun','Sunday'),
  (2,1,1,'Mon','Monday'),
  (3,2,2,'Tue','Tuesday'),
  (4,3,3,'Wed','Wednesday'),
  (5,4,4,'Thu','Thursday'),
  (6,5,5,'Fri','Friday'),
  (7,6,6,'Sat','Saturday')
) dow;

-- cal_gen.make_gregorian_quarter_of_year_v;
create or replace view cal_gen.make_gregorian_quarter_of_year_v as
select 
      col0::smallint as quarter_of_year_nbr
    , col1::char(1) as quarter_of_year_code
    , col2::char(2) as quarter_of_year_abbr
    , col3::varchar as quarter_of_year_name
from (values
  (1,'1','Q1','First Quarter'),
  (2,'2','Q2','Second Quarter'),
  (3,'3','Q3','Third Quarter'),
  (4,'4','Q4','Fourth Quarter')
) qoy;

---------------------------------------------
--from here on down depends on views above --
---------------------------------------------

-- cal_gen.make_gregorian_year_quarter_v;
create or replace view cal_gen.make_gregorian_year_quarter_v as
select 
      year_quarter_nbr::integer as year_quarter_nbr
    , year_quarter_standard_code::char(7) as year_quarter_standard_code
    , year_nbr::smallint as year_nbr
    , quarter_of_year_nbr::smallint as quarter_of_year_nbr
    , year_quarter_from_date::date as year_quarter_from_date
    , year_quarter_thru_date::date as year_quarter_thru_date
    , lag(year_quarter_nbr,1) over (order by year_quarter_nbr) as last_year_quarter_nbr
    , lag(year_quarter_nbr,4) over (order by year_quarter_nbr) as last_year_this_quarter_nbr
from (
    select 
          (y.year_code || q.quarter_of_year_code)::integer as year_quarter_nbr
        , (y.year_code || '-' || q.quarter_of_year_abbr)::char(7) as year_quarter_standard_code
        , y.year_nbr::smallint as year_nbr
        , q.quarter_of_year_nbr::smallint as quarter_of_year_nbr
        , (y.year_code || case when q.quarter_of_year_nbr = 1 then '-01-01' 
                             when q.quarter_of_year_nbr = 2 then '-04-01'
                             when q.quarter_of_year_nbr = 3 then '-07-01'
                             when q.quarter_of_year_nbr = 4 then '-10-01'
                             else null end)::date as year_quarter_from_date
        , (y.year_code || case when q.quarter_of_year_nbr = 1 then '-03-31' 
                             when q.quarter_of_year_nbr = 2 then '-06-30'
                             when q.quarter_of_year_nbr = 3 then '-09-30'
                             when q.quarter_of_year_nbr = 4 then '-12-31'
                             else null end)::date as year_quarter_thru_date
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_quarter_of_year_v q
) yq
--limit 100
;

-- cal_gen.make_gregorian_year_month_v;
create or replace view cal_gen.make_gregorian_year_month_v as
select 
      year_month_nbr::integer as year_month_nbr
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
    select 
          (y.year_code || m.month_of_year_code)::integer as year_month_nbr
        , (y.year_code || '-' || m.month_of_year_code)::char(7) as year_month_standard_code
        , m.month_of_year_nbr
        , (y.year_code || m.quarter_of_year_nbr::varchar)::integer as year_quarter_nbr
        , y.year_nbr
        , (y.year_code || '-' || m.month_of_year_code || '-01')::date as year_month_from_date
        , (y.year_code || '-' || m.month_of_year_code || '-' || 
            case when y.leap_year_ind = 1 then m.leap_year_day_qty::varchar
                 else m.standard_year_day_qty::varchar end)::date as year_month_thru_date
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v m
) ym;

-- cal_gen.make_calendar_date_v;
create or replace view cal_gen.make_calendar_date_v as 
select 
      dt.calendar_date
    , extract(isodow from dt.calendar_date)::smallint as day_of_week_iso_nbr
    , extract(week from dt.calendar_date)::smallint as week_of_year_nbr
    , (extract(isoyear from dt.calendar_date)::varchar || 
        lpad(extract(week from dt.calendar_date)::varchar, 2, '0')
    )::integer as year_week_nbr
    , m.year_month_nbr::integer as year_month_nbr
    , m.year_quarter_nbr::integer as year_quarter_nbr
    , dt.year_nbr::smallint as year_nbr
    , lag(dt.calendar_date, 1) over (order by dt.calendar_date) as yesterday_date
    , (dt.calendar_date - interval 1 week)::date as this_day_last_week
    , (dt.calendar_date - interval 1 month)::date as this_day_last_month
    , (dt.calendar_date - interval 3 months)::date as this_day_last_quarter
    , (dt.calendar_date - interval 1 year)::date as this_day_last_year
from (
    select 
          (y.year_code || '-' || moy.month_of_year_code || '-' || dom.day_of_month_code)::date as calendar_date
        , y.year_nbr
        , moy.month_of_year_nbr
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v moy
    cross join cal_gen.make_day_of_month_v dom
    where dom.day_of_month_nbr <= (case when y.leap_year_ind = 1 then moy.leap_year_day_qty else moy.standard_year_day_qty end)
) dt
left join cal_gen.make_gregorian_year_month_v m
  on dt.year_nbr = m.year_nbr
 and dt.month_of_year_nbr = m.month_of_year_nbr
--limit 100
;

-- cal_gen.make_year_week_v;
create or replace view cal_gen.make_year_week_v as
select 
      year_week_nbr
    , max(week_of_year_nbr) as week_of_year_nbr
    , max(substring(year_week_nbr::varchar, 1, 4))::smallint as year_nbr
    , max(year_nbr::varchar || '-W' || substring(year_week_nbr::varchar, 5, 2))::char(8) as year_week_std_cd
    , min(calendar_date) as week_from_dt
    , max(calendar_date) as week_thru_dt
from cal_gen.make_calendar_date_v
group by year_week_nbr
--limit 100
;

-- cal_gen.make_calendar_date_hour_min_v;
create or replace view cal_gen.make_calendar_date_hour_min_v as 
select 
      (d.calendar_date::varchar || ' ' || h.hour_of_day_code || ':' || m.minute_of_hour_code || ':00')::timestamp as calendar_timestamp
    , d.calendar_date
    , h.hour_of_day_nbr
    , h.hour_of_day_code
    , h.hour_of_day_time
    , h.period_code
    , m.minute_of_hour_nbr
    , m.minute_of_hour_code
from cal_gen.make_calendar_date_v d
cross join cal_gen.make_hour_of_day_v h
cross join cal_gen.make_minute_of_hour_v m;

-- cal_gen.make_calendar_date_hour_v;
create or replace view cal_gen.make_calendar_date_hour_v as 
select 
      (d.calendar_date::varchar || ' ' || h.hour_of_day_time::varchar)::timestamp as calendar_timestamp
    , d.calendar_date
    , h.hour_of_day_nbr
    , h.hour_of_day_code
    , h.hour_of_day_time
    , h.period_code
from cal_gen.make_calendar_date_v d
cross join cal_gen.make_hour_of_day_v h;

-- 2. create calendar tables based on base views and start/end year
-- set calendar start and end years as variables
set variable start_year = 1900;
set variable end_year = 2090;

create table if not exists calendar_ddb.day_of_week as select * from cal_gen.make_day_of_week_v;
create table if not exists calendar_ddb.gregorian_month_of_year as select * from cal_gen.make_gregorian_month_of_year_v;
create table if not exists calendar_ddb.gregorian_quarter_of_year as select * from cal_gen.make_gregorian_quarter_of_year_v;
create table if not exists calendar_ddb.gregorian_year as select * from cal_gen.make_gregorian_year_v where year_nbr between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.gregorian_year_quarter as select * from cal_gen.make_gregorian_year_quarter_v where year_nbr between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.gregorian_year_month as select * from cal_gen.make_gregorian_year_month_v where year_nbr between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.year_week as select * from cal_gen.make_year_week_v where year_nbr between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.calendar_date as select * from cal_gen.make_calendar_date_v where year_nbr between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.hour_of_day as select * from cal_gen.make_hour_of_day_v;
create table if not exists calendar_ddb.minute_of_hour as select * from cal_gen.make_minute_of_hour_v;
create table if not exists calendar_ddb.calendar_date_hour_min as select * from cal_gen.make_calendar_date_hour_min_v where date_part('year', calendar_date) between getvariable('start_year') and getvariable('end_year'); 
create table if not exists calendar_ddb.calendar_date_hour as select * from cal_gen.make_calendar_date_hour_v where date_part('year', calendar_date) between getvariable('start_year') and getvariable('end_year'); 

-- add keys to calendar tables
-- primary keys
alter table calendar_ddb.day_of_week add primary key (day_of_week_iso_nbr);
alter table calendar_ddb.gregorian_month_of_year add primary key (month_of_year_nbr);
alter table calendar_ddb.gregorian_quarter_of_year add primary key (quarter_of_year_nbr);
alter table calendar_ddb.gregorian_year add primary key (year_nbr);
alter table calendar_ddb.gregorian_year_quarter add primary key (year_quarter_nbr);
alter table calendar_ddb.gregorian_year_month add primary key (year_month_nbr);
alter table calendar_ddb.year_week add primary key (year_week_nbr);
alter table calendar_ddb.calendar_date add primary key (calendar_date);
alter table calendar_ddb.hour_of_day add primary key (hour_of_day_nbr);
alter table calendar_ddb.minute_of_hour add primary key (minute_of_hour_nbr);

-- generate transformation tables
-- MTD
create table if not exists calendar_ddb.cumulative_month_to_dates as
select 
      d.calendar_date
    , x.calendar_date as cumulative_month_to_date
from calendar_ddb.calendar_date d 
join calendar_ddb.calendar_date x on d.year_month_nbr = x.year_month_nbr
where x.calendar_date <= d.calendar_date;

-- QTD 
create table if not exists calendar_ddb.cumulative_quarter_to_dates as
select 
      d.calendar_date
    , x.calendar_date as cumulative_quarter_to_date
from calendar_ddb.calendar_date d 
join calendar_ddb.calendar_date x on d.year_quarter_nbr = x.year_quarter_nbr
where x.calendar_date <= d.calendar_date;

-- YTD
create table if not exists calendar_ddb.cumulative_year_to_dates as
select 
      d.calendar_date
    , x.calendar_date as cumulative_year_to_date
from calendar_ddb.calendar_date d 
join calendar_ddb.calendar_date x on d.year_nbr = x.year_nbr
where x.calendar_date <= d.calendar_date;

-- WTD
create table if not exists calendar_ddb.cumulative_week_to_dates as
select 
      d.calendar_date
    , x.calendar_date as cumulative_week_to_date
from calendar_ddb.calendar_date d 
join calendar_ddb.calendar_date x on d.year_week_nbr = x.year_week_nbr
where x.calendar_date <= d.calendar_date;

-- define primary foreign keys for transformation tables
alter table calendar_ddb.cumulative_quarter_to_dates add primary key (calendar_date, cumulative_quarter_to_date);
alter table calendar_ddb.cumulative_year_to_dates add primary key (calendar_date, cumulative_year_to_date);
alter table calendar_ddb.cumulative_week_to_dates add primary key (calendar_date, cumulative_week_to_date);

-- generate calendar_pg views
create or replace view calendar_ddb.day_of_week_v as select *, 1::integer as day_of_week_qty from calendar_ddb.day_of_week;
create or replace view calendar_ddb.month_of_year_v as select *, 1::integer as month_of_year_qty from calendar_ddb.gregorian_month_of_year;
create or replace view calendar_ddb.quarter_of_year_v as select *, 1::integer as quarter_of_year_qty from calendar_ddb.gregorian_quarter_of_year;
create or replace view calendar_ddb.calendar_year_v as select *, 1::integer as calendar_year_qty from calendar_ddb.gregorian_year;
create or replace view calendar_ddb.year_quarter_v as select *, 1::integer as year_quarter_qty from calendar_ddb.gregorian_year_quarter;
create or replace view calendar_ddb.year_month_v as select *, 1::integer as year_month_qty from calendar_ddb.gregorian_year_month;
create or replace view calendar_ddb.year_week_v as select *, 1::integer as year_week_qty from calendar_ddb.year_week;
create or replace view calendar_ddb.calendar_date_v as select *, 1::integer as calendar_date_qty from calendar_ddb.calendar_date;
create or replace view calendar_ddb.calendar_date_hour_min_v as select *, 1::integer as calendar_date_hour_min_qty from calendar_ddb.calendar_date_hour_min; 
create or replace view calendar_ddb.calendar_date_hour_v as select *, 1::integer as calendar_date_hour_qty from calendar_ddb.calendar_date_hour; 
create or replace view calendar_ddb.cumulative_month_to_dates_v as select calendar_date, cumulative_month_to_date from calendar_ddb.cumulative_month_to_dates;
create or replace view calendar_ddb.cumulative_quarter_to_dates_v as select calendar_date, cumulative_quarter_to_date from calendar_ddb.cumulative_quarter_to_dates;
create or replace view calendar_ddb.cumulative_year_to_dates_v as select calendar_date, cumulative_year_to_date from calendar_ddb.cumulative_year_to_dates;
create or replace view calendar_ddb.cumulative_week_to_dates_v as select calendar_date, cumulative_week_to_date from calendar_ddb.cumulative_week_to_dates;
