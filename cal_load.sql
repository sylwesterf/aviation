-- Create date dimension tables
----------------------------------------------------
-- STEPS:
-- 1. Create cal_gen views that generate information about all date/time parts
-- 2. Create calendar tables based on base views and start/end year
----------------------------------------------------

-- 1. Create cal_gen views that generate information about all date/time parts

-- cal_gen.make_gregorian_year_v
create temp table numbers_0_3000 as
select row_number() over (order by true) - 1 as n
from svv_tables          -- any sufficiently large table
limit 3001;              -- from 0 to 3000

-- cal_gen.make_gregorian_year_v;
create or replace view cal_gen.make_gregorian_year_v as
with years as (
    select n as year_nbr,
           lpad(n::varchar, 4, '0') as year_cd
    from numbers_0_3000
    where n between 1000 and 3000
)
select
    year_nbr::smallint                            as year_nbr,
    year_cd::char(4)                              as year_code,
    case
        when mod(year_nbr, 400) = 0 then 1
        when mod(year_nbr, 100) = 0 then 0
        when mod(year_nbr,   4) = 0 then 1
        else 0
    end::smallint                                 as leap_year_ind,
    (year_cd || '-01-01')::date                   as year_from_date,
    (year_cd || '-12-31')::date                   as year_thru_date,
    (year_cd || '-12-31')::date
      - (year_cd || '-01-01')::date              as day_qty,
    lag(year_nbr, 1) over (order by year_nbr)     as last_year_nbr
from years
order by year_nbr;

--cal_gen.make_gregorian_month_of_year_v
CREATE OR REPLACE VIEW cal_gen.make_gregorian_month_of_year_v AS
SELECT  1::SMALLINT AS month_of_year_nbr,
        '01'::CHAR(2) AS month_of_year_code,
        1::SMALLINT AS quarter_of_year_nbr,
        31::SMALLINT AS standard_year_day_qty,
        'Jan'::CHAR(3) AS month_abbrev,
        'January'::VARCHAR(9) AS month_name
UNION ALL SELECT 2, '02', 1, 28, 'Feb', 'February'
UNION ALL SELECT 3, '03', 1, 31, 'Mar', 'March'
UNION ALL SELECT 4, '04', 2, 30, 'Apr', 'April'
UNION ALL SELECT 5, '05', 2, 31, 'May', 'May'
UNION ALL SELECT 6, '06', 2, 30, 'Jun', 'June'
UNION ALL SELECT 7, '07', 3, 31, 'Jul', 'July'
UNION ALL SELECT 8, '08', 3, 31, 'Aug', 'August'
UNION ALL SELECT 9, '09', 3, 30, 'Sep', 'September'
UNION ALL SELECT 10, '10', 4, 31, 'Oct', 'October'
UNION ALL SELECT 11, '11', 4, 30, 'Nov', 'November'
UNION ALL SELECT 12, '12', 4, 31, 'Dec', 'December';

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
with nums as (
    -- generate 0..59 using any sufficiently large system table
    select (row_number() over (order by true) - 1) as n
    from svv_tables
    limit 60
)
select
    lpad(n::varchar, 2, '0')::char(2)  as minute_of_hour_code,
    n::smallint                        as minute_of_hour_nbr
from nums
order by minute_of_hour_nbr;

-- cal_gen.make_day_of_month_v
create or replace view cal_gen.make_day_of_month_v as
with nums as (
    -- generate 1..35 using any sufficiently large system table
    select row_number() over (order by true) as day_of_month_nbr
    from svv_tables
    limit 35
)
select
    day_of_month_nbr::smallint                         as day_of_month_nbr,
    lpad(day_of_month_nbr::varchar, 2, '0')::char(2)   as day_of_month_code
from nums
order by day_of_month_nbr;

-- cal_gen.make_gregorian_month_of_year_v
create or replace view cal_gen.make_gregorian_month_of_year_v as
with months as (
    -- generate 1..12 using svv_tables only as a row source
    select row_number() over (order by 1) as month_of_year_nbr
    from svv_tables
    limit 12
)
select
      m.month_of_year_nbr::smallint                                 as month_of_year_nbr
    , lpad(m.month_of_year_nbr::varchar, 2, '0')::char(2)           as month_of_year_code
    , ((m.month_of_year_nbr - 1) / 3 + 1)::smallint                 as quarter_of_year_nbr

    -- days in a month for a non‑leap year (we use 2021 as a standard year)
    , extract(
          day from
          dateadd(
              day, -1,
              dateadd(
                  month,
                  1,
                  date_trunc(
                      'month',
                      dateadd(month, m.month_of_year_nbr - 1, date '2021-01-01')
                  )
              )
          )
      )::smallint                                                   as standard_year_day_qty

    -- days in a month for a leap year (2020)
    , extract(
          day from
          dateadd(
              day, -1,
              dateadd(
                  month,
                  1,
                  date_trunc(
                      'month',
                      dateadd(month, m.month_of_year_nbr - 1, date '2020-01-01')
                  )
              )
          )
      )::smallint                                                   as leap_year_day_qty

    , to_char(
          dateadd(month, m.month_of_year_nbr - 1, date '2024-01-01'),
          'Mon'
      )::char(3)                                                    as month_of_year_abbr

    , to_char(
          dateadd(month, m.month_of_year_nbr - 1, date '2024-01-01'),
          'Month'
      )::varchar(10)                                                as month_of_year_name
from months m
order by month_of_year_nbr;


-- cal_gen.make_day_of_week_v
CREATE OR REPLACE VIEW cal_gen.make_day_of_week_v AS
SELECT 1::SMALLINT AS day_of_week_common_nbr,  -- Sunday=1
       7::SMALLINT AS day_of_week_iso_nbr,     -- ISO Sunday=7
       0::SMALLINT AS day_of_week_pgsql_nbr,   -- pgsql Sunday=0
       'Sun'::CHAR(3) AS day_of_week_abbr,
       'Sunday'::VARCHAR(10) AS day_of_week_name_eng
UNION ALL SELECT 2, 1, 1, 'Mon', 'Monday'
UNION ALL SELECT 3, 2, 2, 'Tue', 'Tuesday'
UNION ALL SELECT 4, 3, 3, 'Wed', 'Wednesday'
UNION ALL SELECT 5, 4, 4, 'Thu', 'Thursday'
UNION ALL SELECT 6, 5, 5, 'Fri', 'Friday'
UNION ALL SELECT 7, 6, 6, 'Sat', 'Saturday'
ORDER BY day_of_week_iso_nbr;

-- cal_gen.make_gregorian_quarter_of_year_v
CREATE OR REPLACE VIEW cal_gen.make_gregorian_quarter_of_year_v AS
SELECT 1::SMALLINT AS quarter_of_year_nbr,
       '1'::CHAR(1) AS quarter_of_year_code,
       'Q1'::CHAR(2) AS quarter_of_year_abbr,
       'First Quarter'::VARCHAR(15) AS quarter_of_year_name
UNION ALL SELECT 2, '2', 'Q2', 'Second Quarter'
UNION ALL SELECT 3, '3', 'Q3', 'Third Quarter'
UNION ALL SELECT 4, '4', 'Q4', 'Fourth Quarter'
ORDER BY quarter_of_year_nbr;

-- cal_gen.make_gregorian_year_quarter_v
create or replace view cal_gen.make_gregorian_year_quarter_v as
with year_month as (
    -- From years and months we derive a date (first day of each month)
    select
        y.year_nbr,
        y.year_code,
        m.month_of_year_nbr,
        (y.year_code || '-' ||
         lpad(m.month_of_year_nbr::text,2,'0') || '-01')::date as first_day_of_month
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v m
    where y.year_nbr between 1000 and 3000
),
year_quarter_base as (
    -- Group every 3 months to get quarter start/end
    select
        ym.year_nbr,
        ym.year_code,
        ((ym.month_of_year_nbr - 1) / 3 + 1)::smallint as quarter_of_year_nbr,
        min(ym.first_day_of_month)                      as year_quarter_from_date,
        -- last day of quarter: first day of next month after last month in quarter minus 1 day
        dateadd(
            day,
            -1,
            dateadd(month, 1, max(ym.first_day_of_month))
        )                                               as year_quarter_thru_date
    from year_month ym
    group by
        ym.year_nbr,
        ym.year_code,
        ((ym.month_of_year_nbr - 1) / 3 + 1)
)
select
      (yb.year_code || yb.quarter_of_year_nbr::text)::integer     as year_quarter_nbr
    , (yb.year_code || '-Q' || yb.quarter_of_year_nbr::text)::char(7)
                                                                 as year_quarter_standard_code
    , yb.year_nbr::smallint                                       as year_nbr
    , yb.quarter_of_year_nbr::smallint                            as quarter_of_year_nbr
    , yb.year_quarter_from_date::date                             as year_quarter_from_date
    , yb.year_quarter_thru_date::date                             as year_quarter_thru_date
    , lag((yb.year_code || yb.quarter_of_year_nbr::text)::integer, 1)
          over (order by yb.year_nbr, yb.quarter_of_year_nbr)     as last_year_quarter_nbr
    , lag((yb.year_code || yb.quarter_of_year_nbr::text)::integer, 4)
          over (order by yb.year_nbr, yb.quarter_of_year_nbr)     as last_year_this_quarter_nbr
from year_quarter_base yb
order by year_quarter_nbr;

-- cal_gen.make_gregorian_year_month_v
create or replace view cal_gen.make_gregorian_year_month_v as
select
    year_month_nbr::integer                         as year_month_nbr,
    year_month_standard_code::char(7)               as year_month_standard_code,
    month_of_year_nbr::smallint                     as month_of_year_nbr,
    year_quarter_nbr::integer                       as year_quarter_nbr,
    year_nbr::smallint                              as year_nbr,
    year_month_from_date::date                      as year_month_from_date,
    year_month_thru_date::date                      as year_month_thru_date,
    lag(year_month_nbr,1)  over (order by year_month_nbr)  as last_year_month_nbr,
    lag(year_month_nbr,3)  over (order by year_month_nbr)  as last_quarter_this_month_nbr,
    lag(year_month_nbr,12) over (order by year_month_nbr)  as last_year_this_month_nbr
from (
    select
        (y.year_code || m.month_of_year_code)::integer           as year_month_nbr,
        (y.year_code || '-' || m.month_of_year_code)::char(7)    as year_month_standard_code,
        m.month_of_year_nbr                                      as month_of_year_nbr,
        (y.year_code || m.quarter_of_year_nbr::char(1))::integer as year_quarter_nbr,
        y.year_nbr                                               as year_nbr,

        -- First day of month
        (y.year_code || '-' || m.month_of_year_code || '-01')::date
                                                                as year_month_from_date,

        -- Last day of month: first day of next month minus 1 day (with dateadd)
        dateadd(
            day,
            -1,
            dateadd(
                month,
                1,
                (y.year_code || '-' || m.month_of_year_code || '-01')::date
            )
        )                                                       as year_month_thru_date
    from cal_gen.make_gregorian_year_v y
    cross join cal_gen.make_gregorian_month_of_year_v m
    where y.year_nbr between 1000 and 3000
) ym
order by 1;

-- cal_gen.make_calendar_date_v
create or replace view cal_gen.make_calendar_date_v as
with
-- Day generator between 1000‑01‑01 and 3000‑12‑31
nums as (
    select 0 as n
    union all select 1
    union all select 2
    union all select 3
    union all select 4
    union all select 5
    union all select 6
    union all select 7
    union all select 8
    union all select 9
),
seq as (
    -- 10^5 = 100,000 days, enough for range 1000‑3000
    select
        row_number() over (order by 1) - 1 as day_offset
    from nums a
    cross join nums b
    cross join nums c
    cross join nums d
    cross join nums e
),
dates as (
    select
        (date '1000-01-01' + day_offset) as calendar_date
    from seq
    where (date '1000-01-01' + day_offset) <= date '3000-12-31'
),
ymd as (
    select
          d.calendar_date
        , date_part('year',  d.calendar_date)::int  as year_nbr
        , date_part('month', d.calendar_date)::int  as month_of_year_nbr
from dates d
)
select
      ymd.calendar_date
    , (((date_part('dow', ymd.calendar_date) + 6) % 7) + 1)::smallint         as day_of_week_iso_nbr
    , date_part('week', ymd.calendar_date)::smallint                          as week_of_year_nbr
    , (
          to_char(ymd.calendar_date, 'YYYY') ||
          lpad(date_part('week', ymd.calendar_date)::int::varchar(2), 2, '0')
      )::integer                                                              as year_week_nbr
    , m.year_month_nbr
    , m.year_quarter_nbr
    , ymd.year_nbr
    , lead(ymd.calendar_date, 1) over (order by ymd.calendar_date desc)       as yesterday_date
    , dateadd('week',  -1, ymd.calendar_date)::date                           as this_day_last_week
    , dateadd('month', -1, ymd.calendar_date)::date                           as this_day_last_month
    , dateadd('month', -3, ymd.calendar_date)::date                           as this_day_last_quarter
    , dateadd('year',  -1, ymd.calendar_date)::date                           as this_day_last_year
from ymd
left join cal_gen.make_gregorian_year_month_v m
  on  m.year_nbr          = ymd.year_nbr
  and m.month_of_year_nbr = ymd.month_of_year_nbr
order by ymd.calendar_date;

-- cal_gen.make_year_week_v
create or replace view cal_gen.make_year_week_v as
with base as (
    select
          calendar_date
        , extract(week from calendar_date)::smallint              as week_of_year_nbr
        , extract(year from calendar_date)::smallint              as year_nbr
        , (
              to_char(calendar_date, 'YYYY') ||
              lpad(extract(week from calendar_date)::varchar(2), 2, '0')
          )::integer                                              as year_week_nbr
    from cal_gen.make_calendar_date_v
    where calendar_date between date '1000-01-01' and date '3000-12-31'
)
select
      b.year_week_nbr                                            as year_week_nbr
    , max(b.week_of_year_nbr)                                    as week_of_year_nbr
    , max(b.year_nbr)                                            as year_nbr
    , max(
          to_char(b.year_nbr, 'FM0000') || '-W' ||
          lpad(b.week_of_year_nbr::varchar(2), 2, '0')
      )::char(8)                                                 as year_week_std_cd
    , min(b.calendar_date)                                       as week_from_dt
    , max(b.calendar_date)                                       as week_thru_dt
from base b
group by b.year_week_nbr
order by b.year_week_nbr;

-- cal_gen.make_calendar_date_hour_min_v
create or replace view cal_gen.make_calendar_date_hour_min_v as
select
    (d.calendar_date::timestamp
        + (h.hour_of_day_nbr * interval '1 hour')
        + (m.minute_of_hour_nbr * interval '1 minute')) as calendar_timestamp,
    d.calendar_date,
    h.hour_of_day_nbr,
    h.hour_of_day_code,
    h.hour_of_day_time,
    h.period_code,
    m.minute_of_hour_nbr,
    m.minute_of_hour_code
from cal_gen.make_calendar_date_v d
cross join cal_gen.make_hour_of_day_v h
cross join cal_gen.make_minute_of_hour_v m
order by
    d.calendar_date,
    h.hour_of_day_nbr,
    m.minute_of_hour_nbr;

-- cal_gen.make_calendar_date_hour_v
create or replace view cal_gen.make_calendar_date_hour_v as
select
    (d.calendar_date::timestamp
        + (h.hour_of_day_nbr * interval '1 hour')) as calendar_timestamp,
    d.calendar_date,
    h.hour_of_day_nbr,
    h.hour_of_day_code,
    h.hour_of_day_time,
    h.period_code
from cal_gen.make_calendar_date_v d
cross join cal_gen.make_hour_of_day_v h
order by d.calendar_date, h.hour_of_day_nbr;

-------------------------------------------------------------------
-- 2. CALENDAR TABLES IN calendar_pg (1900–2090)
-------------------------------------------------------------------

DROP TABLE IF EXISTS cal_gen.calendar_params;
 
CREATE TABLE cal_gen.calendar_params (
    start_year INT,
    end_year   INT
);
 
INSERT INTO cal_gen.calendar_params (start_year, end_year)
VALUES (1900, 2090);

-- day_of_week
DROP TABLE IF EXISTS calendar_pg.day_of_week;
CREATE TABLE calendar_pg.day_of_week AS
SELECT *
FROM cal_gen.make_day_of_week_v;

CREATE TABLE calendar_pg.day_of_week (
    day_of_week_common_nbr SMALLINT     NOT NULL,
    day_of_week_iso_nbr    SMALLINT     NOT NULL,
    day_of_week_pgsql_nbr  SMALLINT     NOT NULL,
    day_of_week_abbr       CHAR(3)      NOT NULL,
    day_of_week_name_eng   VARCHAR(10)  NOT NULL
);
 
-- gregorian_month_of_year
DROP TABLE IF EXISTS calendar_pg.gregorian_month_of_year;
CREATE TABLE calendar_pg.gregorian_month_of_year AS
SELECT *
FROM cal_gen.make_gregorian_month_of_year_v;
 
-- gregorian_quarter_of_year
DROP TABLE IF EXISTS calendar_pg.gregorian_quarter_of_year;
CREATE TABLE calendar_pg.gregorian_quarter_of_year AS
SELECT *
FROM cal_gen.make_gregorian_quarter_of_year_v;
 
-- gregorian_year
DROP TABLE IF EXISTS calendar_pg.gregorian_year;
CREATE TABLE calendar_pg.gregorian_year AS
SELECT y.*
FROM cal_gen.make_gregorian_year_v y
CROSS JOIN cal_gen.calendar_params p
WHERE y.year_nbr BETWEEN p.start_year AND p.end_year;
 
-- gregorian_year_quarter
DROP TABLE IF EXISTS calendar_pg.gregorian_year_quarter;
CREATE TABLE calendar_pg.gregorian_year_quarter AS
SELECT yq.*
FROM cal_gen.make_gregorian_year_quarter_v yq
CROSS JOIN cal_gen.calendar_params p
WHERE yq.year_nbr BETWEEN p.start_year AND p.end_year;
 
-- gregorian_year_month
DROP TABLE IF EXISTS calendar_pg.gregorian_year_month;
CREATE TABLE calendar_pg.gregorian_year_month AS
SELECT ym.*
FROM cal_gen.make_gregorian_year_month_v ym
CROSS JOIN cal_gen.calendar_params p
WHERE ym.year_nbr BETWEEN p.start_year AND p.end_year;
 
-- year_week
DROP TABLE IF EXISTS calendar_pg.year_week;
CREATE TABLE calendar_pg.year_week AS
SELECT w.*
FROM cal_gen.make_year_week_v w
CROSS JOIN cal_gen.calendar_params p
WHERE w.year_nbr BETWEEN p.start_year AND p.end_year;
 
-- calendar_date
DROP TABLE IF EXISTS calendar_pg.calendar_date;
CREATE TABLE calendar_pg.calendar_date AS
SELECT d.*
FROM cal_gen.make_calendar_date_v d
CROSS JOIN cal_gen.calendar_params p
WHERE d.year_nbr BETWEEN p.start_year AND p.end_year;
 
-- hour_of_day
DROP TABLE IF EXISTS calendar_pg.hour_of_day;
CREATE TABLE calendar_pg.hour_of_day AS
SELECT *
FROM cal_gen.make_hour_of_day_v;
 
-- minute_of_hour
DROP TABLE IF EXISTS calendar_pg.minute_of_hour;
CREATE TABLE calendar_pg.minute_of_hour AS
SELECT *
FROM cal_gen.make_minute_of_hour_v;
 
-- calendar_date_hour_min
DROP TABLE IF EXISTS calendar_pg.calendar_date_hour_min;
CREATE TABLE calendar_pg.calendar_date_hour_min AS
SELECT chm.*
FROM cal_gen.make_calendar_date_hour_min_v chm
CROSS JOIN cal_gen.calendar_params p
WHERE DATE_PART('year', chm.calendar_date) BETWEEN p.start_year AND p.end_year;
 
-- calendar_date_hour
DROP TABLE IF EXISTS calendar_pg.calendar_date_hour;
CREATE TABLE calendar_pg.calendar_date_hour AS
SELECT ch.*
FROM cal_gen.make_calendar_date_hour_v ch
CROSS JOIN cal_gen.calendar_params p
WHERE DATE_PART('year', ch.calendar_date) BETWEEN p.start_year AND p.end_year;

-------------------------------------------------------------------
-- 3. PRIMARY KEYS AND INDEX 
-------------------------------------------------------------------

COMMENT ON TABLE calendar_pg.day_of_week IS 'Monday is the first day of the working week, ISO 2105/8601.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_common_nbr IS 'This number begins with Sunday as 1, and is in common usage.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_pgsql_nbr IS 'PostgreSQL functions list Sunday as 0, and Saturday as 6.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_abbr IS 'Standard abbreviation of the day of week (in English).';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_name_eng IS 'The full name of the day of the week (in English).';

COMMENT ON TABLE calendar_pg.gregorian_month_of_year IS 'Gregorian Years have 12 months, and have since it evolved from Roman years.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.standard_year_day_qty IS 'The number of Days within this month for a Standard Year.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.leap_year_day_qty IS 'The number of days within this month during a Leap Year.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.month_of_year_name IS 'The word which identifies this month.';

COMMENT ON TABLE calendar_pg.gregorian_quarter_of_year IS 'A quarter is a standard interval consisting of three months, and generally analogous to a "season", which is in keeping with the agricultural purpose of the calendar.';

COMMENT ON TABLE calendar_pg.gregorian_year IS 'A year represents the number of orbits by the earth around the sun within the Common Era (CE), defined by Pope Gregory XIII in October 1582.';
COMMENT ON COLUMN calendar_pg.gregorian_year.year_nbr IS 'A modern year is a four digit number.';

COMMENT ON TABLE calendar_pg.gregorian_year_quarter IS 'This is the natural list of quarters within a specific year.';
COMMENT ON COLUMN calendar_pg.gregorian_year_quarter.year_nbr IS 'The year containing this year-quarter.';

COMMENT ON TABLE calendar_pg.gregorian_year_month IS 'This is the natural list of months within a specific year.';

COMMENT ON TABLE calendar_pg.year_week IS 'This is the natural list of weeks within a specific year.';
COMMENT ON COLUMN calendar_pg.year_week.year_week_nbr IS 'The numbered weeks within a year.';
COMMENT ON COLUMN calendar_pg.year_week.year_nbr IS 'The year that contains this week.';

COMMENT ON TABLE calendar_pg.calendar_date IS 'A calendar day represents the spin of the earth on its axis, providing a day and night cycle.';
COMMENT ON COLUMN calendar_pg.calendar_date.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_pg.calendar_date.year_week_nbr IS 'Weeks always have seven days, and each is assigned a number within a year; week 1 contains January 1 for that year.';

COMMENT ON TABLE calendar_pg.hour_of_day IS 'Our 24-hour day comes from the ancient Egyptians who divided day-time into 10 hours they measured with devices such as shadow clocks, and added a twilight hour at the beginning and another one at the end of the day-time.';
COMMENT ON COLUMN calendar_pg.hour_of_day.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

COMMENT ON TABLE calendar_pg.minute_of_hour IS 'The division of the hour into 60 minutes and of the minute into 60 seconds comes from ancient civilizations - Babylonians, Sumerians and Egyptians - who had different numbering systems; base 12 (duodecimal) and base 60 (sexagesimal) for mathematics.';

COMMENT ON TABLE calendar_pg.calendar_date_hour_min IS 'A comprehensive timeline with minute-level granularity made by combining calendar dates, hours of the day, and minutes of the hour.';
COMMENT ON COLUMN calendar_pg.calendar_date_hour_min.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

COMMENT ON TABLE calendar_pg.calendar_date_hour IS 'A series of timestamps with hourly granularity by combining calendar dates and hours of the day.';

-- PRIMARY KEYS
alter table calendar_pg.day_of_week
  add constraint day_of_week_pk primary key (day_of_week_iso_nbr);


  /*DROP TABLE IF EXISTS calendar_pg.day_of_week;

CREATE TABLE calendar_pg.day_of_week (
    day_of_week_common_nbr SMALLINT     NOT NULL,
    day_of_week_iso_nbr    SMALLINT     NOT NULL,
    day_of_week_pgsql_nbr  SMALLINT     NOT NULL,
    day_of_week_abbr       CHAR(3)      NOT NULL,
    day_of_week_name_eng   VARCHAR(10)  NOT NULL
);

INSERT INTO calendar_pg.day_of_week
SELECT *
FROM cal_gen.make_day_of_week_v;

ALTER TABLE calendar_pg.day_of_week
ADD CONSTRAINT day_of_week_pk PRIMARY KEY (day_of_week_iso_nbr);*/

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

-- INDEXES (declarative; in Redshift they are logical)
CREATE UNIQUE INDEX gregorian_month_of_year_ak1
  ON calendar_pg.gregorian_month_of_year (month_of_year_code);

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
  on calendar_pg.year_week (year_nbr);*/

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
DROP TABLE IF EXISTS calendar_pg.cumulative_month_to_dates;
 
CREATE TABLE calendar_pg.cumulative_month_to_dates AS
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_month_to_date
FROM calendar_pg.calendar_date d
JOIN calendar_pg.calendar_date x 
  ON d.year_month_nbr = x.year_month_nbr
WHERE x.calendar_date <= d.calendar_date
  AND x.calendar_date <= (SELECT MAX(calendar_date)
                          FROM calendar_pg.calendar_date);
 
-- QTD
DROP TABLE IF EXISTS calendar_pg.cumulative_quarter_to_dates;
 
CREATE TABLE calendar_pg.cumulative_quarter_to_dates AS
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_quarter_to_date
FROM calendar_pg.calendar_date d
JOIN calendar_pg.calendar_date x 
  ON d.year_quarter_nbr = x.year_quarter_nbr
WHERE x.calendar_date <= d.calendar_date;
 
-- YTD
DROP TABLE IF EXISTS calendar_pg.cumulative_year_to_dates;
 
CREATE TABLE calendar_pg.cumulative_year_to_dates AS
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_year_to_date
FROM calendar_pg.calendar_date d
JOIN calendar_pg.calendar_date x 
  ON d.year_nbr = x.year_nbr
WHERE x.calendar_date <= d.calendar_date;
 
-- WTD
DROP TABLE IF EXISTS calendar_pg.cumulative_week_to_dates;
 
CREATE TABLE calendar_pg.cumulative_week_to_dates AS
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_week_to_date
FROM calendar_pg.calendar_date d
JOIN calendar_pg.calendar_date x 
  ON d.year_week_nbr = x.year_week_nbr
WHERE x.calendar_date <= d.calendar_date;
 
-- add comments to transformation tables
COMMENT ON TABLE calendar_pg.cumulative_year_to_dates IS 'Time transformation for MSTR, relates calendar_date to Year-To-Date (YTD) cumulative dates.';
COMMENT ON TABLE calendar_pg.cumulative_quarter_to_dates IS 'Time transformation for MSTR, relates calendar_date to Quarter-To-Date (QTD) cumulative dates.';
COMMENT ON TABLE calendar_pg.cumulative_month_to_dates IS 'Time transformation for MSTR, relates calendar_date to Month-To-Date (MTD) cumulative dates.';
COMMENT ON TABLE calendar_pg.cumulative_week_to_dates IS 'Time transformation for MSTR, relates calendar_date to Week-To-Date (WTD) cumulative dates.';

-- define primary and fereign keys for transformation tables
-- calendar_pg.cumulative_quarter_to_dates:
alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_pk primary key (calendar_date, cumulative_quarter_to_date);
alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_base_date_fk foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);
alter table calendar_pg.cumulative_quarter_to_dates 
  add constraint cumulative_quarter_to_dates_qtd_date_fk foreign key (cumulative_quarter_to_date)
  references calendar_pg.calendar_date (calendar_date);
 
-- calendar_pg.cumulative_year_to_dates:
alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_pk primary key (calendar_date, cumulative_year_to_date);
alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_base_date_fk foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);
alter table calendar_pg.cumulative_year_to_dates 
  add constraint cumulative_year_to_dates_qtd_date_fk foreign key (cumulative_year_to_date)
  references calendar_pg.calendar_date (calendar_date);
 
-- calendar_pg.cumulative_year_to_dates:
alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_pk primary key (calendar_date, cumulative_week_to_date);
alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_base_date_fk foreign key (calendar_date)
  references calendar_pg.calendar_date (calendar_date);
alter table calendar_pg.cumulative_week_to_dates 
  add constraint cumulative_week_to_dates_qtd_date_fk foreign key (cumulative_week_to_date)
  references calendar_pg.calendar_date (calendar_date);
  
-------------------------------------------------------------------
-- 6. Views calendar_pg
-------------------------------------------------------------------

create or replace view calendar_pg.day_of_week_v as select *, 1::integer as day_of_week_qty from calendar_pg.day_of_week;
create or replace view calendar_pg.month_of_year_v as select *, 1::integer as month_of_year_qty from calendar_pg.gregorian_month_of_year;
create or replace view calendar_pg.quarter_of_year_v as select *, 1::integer as quarter_of_year_qty from calendar_pg.gregorian_quarter_of_year;
create or replace view calendar_pg.calendar_year_v as select *, 1::integer as calendar_year_qty from calendar_pg.gregorian_year;
create or replace view calendar_pg.year_quarter_v as select *, 1::integer as year_quarter_qty from calendar_pg.gregorian_year_quarter;
create or replace view calendar_pg.year_month_v as select *, 1::integer as year_month_qty from calendar_pg.gregorian_year_month;
create or replace view calendar_pg.year_week_v as select *, 1::integer as year_week_qty from calendar_pg.year_week;
create or replace view calendar_pg.calendar_date_v as select *, 1::integer as calendar_date_qty from calendar_pg.calendar_date;
create or replace view calendar_pg.calendar_date_hour_min_v as select *, 1::integer as calendar_date_hour_min_qty from calendar_pg.calendar_date_hour_min;
create or replace view calendar_pg.calendar_date_hour_v as select *, 1::integer as calendar_date_hour_qty from calendar_pg.calendar_date_hour;
create or replace view calendar_pg.cumulative_month_to_dates_v as select calendar_date, cumulative_month_to_date from calendar_pg.cumulative_month_to_dates;
create or replace view calendar_pg.cumulative_quarter_to_dates_v as select calendar_date, cumulative_quarter_to_date from calendar_pg.cumulative_quarter_to_dates;
create or replace view calendar_pg.cumulative_year_to_dates_v as select calendar_date, cumulative_year_to_date from calendar_pg.cumulative_year_to_dates;
create or replace view calendar_pg.cumulative_week_to_dates_v as select calendar_date, cumulative_week_to_date from calendar_pg.cumulative_week_to_dates;