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
    select row_number() over (order by true) as day_of_month_nbr
    from svv_tables
    limit 35
)
select
    day_of_month_nbr::smallint                         as day_of_month_nbr,
    lpad(day_of_month_nbr::varchar, 2, '0')::char(2)   as day_of_month_code
from nums
order by day_of_month_nbr;

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
select
      (y.year_code || q.quarter_of_year_nbr::text)::integer          as year_quarter_nbr
    , (y.year_code || '-Q' || q.quarter_of_year_nbr::text)::char(7)  as year_quarter_standard_code
    , y.year_nbr::smallint                                            as year_nbr
    , q.quarter_of_year_nbr::smallint                                 as quarter_of_year_nbr
    , (y.year_code || case q.quarter_of_year_nbr
                        when 1 then '-01-01'
                        when 2 then '-04-01'
                        when 3 then '-07-01'
                        when 4 then '-10-01'
                      end)::date                                      as year_quarter_from_date
    , (y.year_code || case q.quarter_of_year_nbr
                        when 1 then '-03-31'
                        when 2 then '-06-30'
                        when 3 then '-09-30'
                        when 4 then '-12-31'
                      end)::date                                      as year_quarter_thru_date
    , lag((y.year_code || q.quarter_of_year_nbr::text)::integer, 1)
          over (order by y.year_nbr, q.quarter_of_year_nbr)          as last_year_quarter_nbr
    , lag((y.year_code || q.quarter_of_year_nbr::text)::integer, 4)
          over (order by y.year_nbr, q.quarter_of_year_nbr)          as last_year_this_quarter_nbr
from cal_gen.make_gregorian_year_v y
cross join cal_gen.make_gregorian_quarter_of_year_v q
where y.year_nbr between 1000 and 3000
order by year_quarter_nbr;

-- cal_gen.make_gregorian_year_month_v 
create or replace view cal_gen.make_gregorian_year_month_v as
select
      (y.year_code || m.month_of_year_code)::integer                as year_month_nbr
    , (y.year_code || '-' || m.month_of_year_code)::char(7)         as year_month_standard_code
    , m.month_of_year_nbr::smallint                                  as month_of_year_nbr
    , (y.year_code || m.quarter_of_year_nbr::char(1))::integer       as year_quarter_nbr
    , y.year_nbr::smallint                                           as year_nbr
    , (y.year_code || '-' || m.month_of_year_code || '-01')::date    as year_month_from_date
    , dateadd(day, -1,
        dateadd(month, 1,
          (y.year_code || '-' || m.month_of_year_code || '-01')::date
        )
      )                                                              as year_month_thru_date
    , lag((y.year_code || m.month_of_year_code)::integer,  1)
          over (order by y.year_code, m.month_of_year_nbr)          as last_year_month_nbr
    , lag((y.year_code || m.month_of_year_code)::integer,  3)
          over (order by y.year_code, m.month_of_year_nbr)          as last_quarter_this_month_nbr
    , lag((y.year_code || m.month_of_year_code)::integer, 12)
          over (order by y.year_code, m.month_of_year_nbr)          as last_year_this_month_nbr
from cal_gen.make_gregorian_year_v y
cross join cal_gen.make_gregorian_month_of_year_v m
where y.year_nbr between 1000 and 3000
order by year_month_nbr;

-- cal_gen.make_calendar_date_v
create or replace view cal_gen.make_calendar_date_v as
with nums as (
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
dates as (
    select dateadd(day, (a.n * 10000 + b.n * 1000 + c.n * 100 + d.n * 10 + e.n), date '1000-01-01') as calendar_date
    from nums a
    cross join nums b
    cross join nums c
    cross join nums d
    cross join nums e
    where dateadd(day, (a.n * 10000 + b.n * 1000 + c.n * 100 + d.n * 10 + e.n), date '1000-01-01') <= date '3000-12-31'
)
select
      d.calendar_date
    , (((date_part('dow', d.calendar_date)::int + 6) % 7) + 1)::smallint      as day_of_week_iso_nbr
    , date_part('week', d.calendar_date)::smallint                             as week_of_year_nbr
    , (to_char(d.calendar_date, 'IYYY') ||
       lpad(to_char(d.calendar_date, 'IW'), 2, '0'))::integer                 as year_week_nbr
    , m.year_month_nbr
    , m.year_quarter_nbr
    , date_part('year', d.calendar_date)::smallint                             as year_nbr
    , dateadd(day,   -1, d.calendar_date)::date                                as yesterday_date
    , dateadd(week,  -1, d.calendar_date)::date                                as this_day_last_week
    , dateadd(month, -1, d.calendar_date)::date                                as this_day_last_month
    , dateadd(month, -3, d.calendar_date)::date                                as this_day_last_quarter
    , dateadd(year,  -1, d.calendar_date)::date                                as this_day_last_year
from dates d
left join cal_gen.make_gregorian_year_month_v m
  on  date_part('year',  d.calendar_date)::int = m.year_nbr
  and date_part('month', d.calendar_date)::int = m.month_of_year_nbr
order by d.calendar_date;

-- cal_gen.make_year_week_v
create or replace view cal_gen.make_year_week_v as
select
      year_week_nbr
    , max(week_of_year_nbr)::smallint                                as week_of_year_nbr
    , max(substring(year_week_nbr::varchar(6), 1, 4))::smallint      as year_nbr
    , max(substring(year_week_nbr::varchar(6), 1, 4) || '-W' ||
          substring(year_week_nbr::varchar(6), 5, 2))::char(8)       as year_week_std_cd
    , min(calendar_date)::date                                        as week_from_dt
    , max(calendar_date)::date                                        as week_thru_dt
from cal_gen.make_calendar_date_v
where year_nbr between 1000 and 3000
group by year_week_nbr
order by year_week_nbr;

-- cal_gen.make_calendar_date_hour_min_v
create or replace view cal_gen.make_calendar_date_hour_min_v as
select
      dateadd(minute, m.minute_of_hour_nbr,
        dateadd(hour, h.hour_of_day_nbr, d.calendar_date::timestamp)
      )                                                          as calendar_timestamp
    , d.calendar_date
    , h.hour_of_day_nbr
    , h.hour_of_day_code
    , h.hour_of_day_time
    , h.period_code
    , m.minute_of_hour_nbr
    , m.minute_of_hour_code
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


-- add keys to calendar tables
-- primary keys (already defined inline above)

-- add indexes for calendar_pg tables
CREATE UNIQUE INDEX gregorian_month_of_year_ak1 ON calendar_rs.gregorian_month_of_year (month_of_year_code);
CREATE UNIQUE INDEX gregorian_year_quarter_ak1 ON calendar_rs.gregorian_year_quarter (year_quarter_standard_code);
CREATE UNIQUE INDEX year_week_ak1 ON calendar_rs.year_week (year_nbr, week_of_year_nbr);
CREATE INDEX calendar_date_year_week_if1 ON calendar_rs.calendar_date (year_week_nbr);
CREATE INDEX calendar_date_year_month_if2 ON calendar_rs.calendar_date (year_month_nbr);
CREATE INDEX calendar_date_day_of_week_if3 ON calendar_rs.calendar_date (day_of_week_iso_nbr);
CREATE INDEX gregorian_month_of_year_quarter_of_year_if1 ON calendar_rs.gregorian_month_of_year (quarter_of_year_nbr);
CREATE INDEX gregorian_year_month_year_quarter_if1 ON calendar_rs.gregorian_year_month (year_quarter_nbr);
CREATE INDEX gregorian_year_month_of_year_if1 ON calendar_rs.gregorian_year_month (month_of_year_nbr);
CREATE INDEX gregorian_year_quarter_year_if1 ON calendar_rs.gregorian_year_quarter (year_nbr);
CREATE INDEX gregorian_year_quarter_of_year_if2 ON calendar_rs.gregorian_year_quarter (quarter_of_year_nbr);
CREATE INDEX year_week_if1 ON calendar_rs.year_week (year_nbr);

-- define foreign keys to calendar_pg tables
ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_year_week_fk
FOREIGN KEY (year_week_nbr) REFERENCES calendar_rs.year_week (year_week_nbr);

ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_year_month_fk
FOREIGN KEY (year_month_nbr) REFERENCES calendar_rs.gregorian_year_month (year_month_nbr);

ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_day_of_week_fk
FOREIGN KEY (day_of_week_iso_nbr) REFERENCES calendar_rs.day_of_week (day_of_week_iso_nbr);

ALTER TABLE calendar_rs.gregorian_month_of_year ADD CONSTRAINT gregorian_month_of_year_quarter_of_year_fk
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_rs.gregorian_quarter_of_year (quarter_of_year_nbr);

ALTER TABLE calendar_rs.gregorian_year_month ADD CONSTRAINT gregorian_year_month_year_quarter_fk
FOREIGN KEY (year_quarter_nbr) REFERENCES calendar_rs.gregorian_year_quarter (year_quarter_nbr);

ALTER TABLE calendar_rs.gregorian_year_month ADD CONSTRAINT gregorian_year_month_month_of_year_fk
FOREIGN KEY (month_of_year_nbr) REFERENCES calendar_rs.gregorian_month_of_year (month_of_year_nbr);

ALTER TABLE calendar_rs.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_year_fk
FOREIGN KEY (year_nbr) REFERENCES calendar_rs.gregorian_year (year_nbr);

ALTER TABLE calendar_rs.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_quarter_of_year_fk
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_rs.gregorian_quarter_of_year (quarter_of_year_nbr);

ALTER TABLE calendar_rs.year_week ADD CONSTRAINT year_week_gregorian_year_fk
FOREIGN KEY (year_nbr) REFERENCES calendar_rs.gregorian_year (year_nbr);

ALTER TABLE calendar_rs.calendar_date_hour_min ADD CONSTRAINT calendar_date_hour_min_calendar_date_fk
FOREIGN KEY (calendar_date) REFERENCES calendar_rs.calendar_date (calendar_date);

ALTER TABLE calendar_rs.calendar_date_hour ADD CONSTRAINT calendar_date_hour_calendar_date_fk
FOREIGN KEY (calendar_date) REFERENCES calendar_rs.calendar_date (calendar_date);


-- add comments to calendar tables
COMMENT ON TABLE calendar_rs.day_of_week IS 'Monday is the first day of the working week, ISO 2105/8601.';
COMMENT ON COLUMN calendar_rs.day_of_week.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_rs.day_of_week.day_of_week_common_nbr IS 'This number begins with Sunday as 1, and is in common usage.';
COMMENT ON COLUMN calendar_rs.day_of_week.day_of_week_pgsql_nbr IS 'PostgreSQL functions list Sunday as 0, and Saturday as 6.';
COMMENT ON COLUMN calendar_rs.day_of_week.day_of_week_abbr IS 'Standard abbreviation of the day of week (in English).';
COMMENT ON COLUMN calendar_rs.day_of_week.day_of_week_name_eng IS 'The full name of the day of the week (in English).';

COMMENT ON TABLE calendar_rs.gregorian_month_of_year IS 'Gregorian Years have 12 months, and have since it evolved from Roman years.';
COMMENT ON COLUMN calendar_rs.gregorian_month_of_year.standard_year_day_qty IS 'The number of Days within this month for a Standard Year.';
COMMENT ON COLUMN calendar_rs.gregorian_month_of_year.leap_year_day_qty IS 'The number of days within this month during a Leap Year.';
COMMENT ON COLUMN calendar_rs.gregorian_month_of_year.month_of_year_name IS 'The word which identifies this month.';

COMMENT ON TABLE calendar_rs.gregorian_quarter_of_year IS 'A quarter is a standard interval consisting of three months, and generally analogous to a "season", which is in keeping with the agricultural purpose of the calendar.';

COMMENT ON TABLE calendar_rs.gregorian_year IS 'A year represents the number of orbits by the earth around the sun within the Common Era (CE), defined by Pope Gregory XIII in October 1582.';
COMMENT ON COLUMN calendar_rs.gregorian_year.year_nbr IS 'A modern year is a four digit number.';

COMMENT ON TABLE calendar_rs.gregorian_year_quarter IS 'This is the natural list of quarters within a specific year.';
COMMENT ON COLUMN calendar_rs.gregorian_year_quarter.year_nbr IS 'The year containing this year-quarter.';

COMMENT ON TABLE calendar_rs.gregorian_year_month IS 'This is the natural list of months within a specific year.';

COMMENT ON TABLE calendar_rs.year_week IS 'This is the natural list of weeks within a specific year.';
COMMENT ON COLUMN calendar_rs.year_week.year_week_nbr IS 'The numbered weeks within a year.';
COMMENT ON COLUMN calendar_rs.year_week.year_nbr IS 'The year that contains this week.';

COMMENT ON TABLE calendar_rs.calendar_date IS 'A calendar day represents the spin of the earth on its axis, providing a day and night cycle.';
COMMENT ON COLUMN calendar_rs.calendar_date.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_rs.calendar_date.year_week_nbr IS 'Weeks always have seven days, and each is assigned a number within a year; week 1 contains January 1 for that year.';

COMMENT ON TABLE calendar_rs.hour_of_day IS 'Our 24-hour day comes from the ancient Egyptians who divided day-time into 10 hours they measured with devices such as shadow clocks, and added a twilight hour at the beginning and another one at the end of the day-time.';
COMMENT ON COLUMN calendar_rs.hour_of_day.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

COMMENT ON TABLE calendar_rs.minute_of_hour IS 'The division of the hour into 60 minutes and of the minute into 60 seconds comes from ancient civilizations - Babylonians, Sumerians and Egyptians - who had different numbering systems; base 12 (duodecimal) and base 60 (sexagesimal) for mathematics.';

COMMENT ON TABLE calendar_rs.calendar_date_hour_min IS 'A comprehensive timeline with minute-level granularity made by combining calendar dates, hours of the day, and minutes of the hour.';
COMMENT ON COLUMN calendar_rs.calendar_date_hour_min.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

COMMENT ON TABLE calendar_rs.calendar_date_hour IS 'A series of timestamps with hourly granularity by combining calendar dates and hours of the day.';


-- define foreign keys to calendar tables
ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_year_week_fk 
FOREIGN KEY (year_week_nbr) REFERENCES calendar_rs.year_week (year_week_nbr);
ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_year_month_fk 
FOREIGN KEY (year_month_nbr) REFERENCES calendar_rs.gregorian_year_month (year_month_nbr);
ALTER TABLE calendar_rs.calendar_date ADD CONSTRAINT calendar_date_day_of_week_fk 
FOREIGN KEY (day_of_week_iso_nbr) REFERENCES calendar_rs.day_of_week (day_of_week_iso_nbr);
ALTER TABLE calendar_rs.gregorian_month_of_year ADD CONSTRAINT gregorian_month_of_year_quarter_of_year_fk  
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_rs.gregorian_quarter_of_year (quarter_of_year_nbr);
ALTER TABLE calendar_rs.gregorian_year_month ADD CONSTRAINT gregorian_year_month_year_quarter_fk 
FOREIGN KEY (year_quarter_nbr) REFERENCES calendar_rs.gregorian_year_quarter (year_quarter_nbr);
ALTER TABLE calendar_rs.gregorian_year_month ADD CONSTRAINT gregorian_year_month_month_of_year_fk 
FOREIGN KEY (month_of_year_nbr) REFERENCES calendar_rs.gregorian_month_of_year (month_of_year_nbr);
ALTER TABLE calendar_rs.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_year_fk 
FOREIGN KEY (year_nbr) REFERENCES calendar_rs.gregorian_year (year_nbr);
ALTER TABLE calendar_rs.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_quarter_of_year_fk 
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_rs.gregorian_quarter_of_year (quarter_of_year_nbr);
ALTER TABLE calendar_rs.year_week ADD CONSTRAINT year_week_gregorian_year_fk  
FOREIGN KEY (year_nbr) REFERENCES calendar_rs.gregorian_year (year_nbr);
alter table calendar_rs.calendar_date_hour_min  add constraint calendar_date_hour_min_calendar_date_fk 
foreign key (calendar_date) references calendar_rs.calendar_date (calendar_date);
alter table calendar_rs.calendar_date_hour  add constraint calendar_date_hour_calendar_date_fk 
foreign key (calendar_date) references calendar_rs.calendar_date (calendar_date);

-- generate transformation tables
-- MTD
-- TODO as other calendar tables pattern CREATE with a PK + INSERT
DROP TABLE IF EXISTS calendar_rs.cumulative_month_to_dates;
CREATE TABLE calendar_rs.cumulative_month_to_dates (
    calendar_date               DATE    NOT NULL,
    cumulative_month_to_date    DATE    NOT NULL,
    PRIMARY KEY (calendar_date, cumulative_month_to_date)
);
INSERT INTO calendar_rs.cumulative_month_to_dates
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_month_to_date
FROM calendar_rs.calendar_date d
JOIN calendar_rs.calendar_date x 
  ON d.year_month_nbr = x.year_month_nbr
WHERE x.calendar_date <= d.calendar_date
  AND x.calendar_date <= (SELECT MAX(calendar_date)
                          FROM calendar_rs.calendar_date);

-- QTD
DROP TABLE IF EXISTS calendar_rs.cumulative_quarter_to_dates;
CREATE TABLE calendar_rs.cumulative_quarter_to_dates (
    calendar_date               DATE    NOT NULL,
    cumulative_quarter_to_date  DATE    NOT NULL,
    PRIMARY KEY (calendar_date, cumulative_quarter_to_date)
);
INSERT INTO calendar_rs.cumulative_quarter_to_dates
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_quarter_to_date
FROM calendar_rs.calendar_date d
JOIN calendar_rs.calendar_date x 
  ON d.year_quarter_nbr = x.year_quarter_nbr
WHERE x.calendar_date <= d.calendar_date;

-- YTD
DROP TABLE IF EXISTS calendar_rs.cumulative_year_to_dates;
CREATE TABLE calendar_rs.cumulative_year_to_dates (
    calendar_date               DATE    NOT NULL,
    cumulative_year_to_date     DATE    NOT NULL,
    PRIMARY KEY (calendar_date, cumulative_year_to_date)
);
INSERT INTO calendar_rs.cumulative_year_to_dates
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_year_to_date
FROM calendar_rs.calendar_date d
JOIN calendar_rs.calendar_date x 
  ON d.year_nbr = x.year_nbr
WHERE x.calendar_date <= d.calendar_date;

-- WTD
DROP TABLE IF EXISTS calendar_rs.cumulative_week_to_dates;
CREATE TABLE calendar_rs.cumulative_week_to_dates (
    calendar_date               DATE    NOT NULL,
    cumulative_week_to_date     DATE    NOT NULL,
    PRIMARY KEY (calendar_date, cumulative_week_to_date)
);
INSERT INTO calendar_rs.cumulative_week_to_dates
SELECT  d.calendar_date,
        x.calendar_date AS cumulative_week_to_date
FROM calendar_rs.calendar_date d
JOIN calendar_rs.calendar_date x 
  ON d.year_week_nbr = x.year_week_nbr
WHERE x.calendar_date <= d.calendar_date;

-- add comments to transformation tables
COMMENT ON TABLE calendar_rs.cumulative_year_to_dates IS 'Time transformation for MSTR, relates calendar_date to Year-To-Date (YTD) cumulative dates.';
COMMENT ON TABLE calendar_rs.cumulative_quarter_to_dates IS 'Time transformation for MSTR, relates calendar_date to Quarter-To-Date (QTD) cumulative dates.';
COMMENT ON TABLE calendar_rs.cumulative_month_to_dates IS 'Time transformation for MSTR, relates calendar_date to Month-To-Date (MTD) cumulative dates.';
COMMENT ON TABLE calendar_rs.cumulative_week_to_dates IS 'Time transformation for MSTR, relates calendar_date to Week-To-Date (WTD) cumulative dates.';


-- define foreign keys for transformation tables
-- calendar_rs.cumulative_month_to_dates:
ALTER TABLE calendar_rs.cumulative_month_to_dates
  ADD CONSTRAINT cumulative_month_to_dates_base_date_fk FOREIGN KEY (calendar_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);
ALTER TABLE calendar_rs.cumulative_month_to_dates
  ADD CONSTRAINT cumulative_month_to_dates_mtd_date_fk FOREIGN KEY (cumulative_month_to_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);

-- calendar_rs.cumulative_quarter_to_dates:
ALTER TABLE calendar_rs.cumulative_quarter_to_dates
  ADD CONSTRAINT cumulative_quarter_to_dates_base_date_fk FOREIGN KEY (calendar_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);
ALTER TABLE calendar_rs.cumulative_quarter_to_dates
  ADD CONSTRAINT cumulative_quarter_to_dates_qtd_date_fk FOREIGN KEY (cumulative_quarter_to_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);

-- calendar_rs.cumulative_year_to_dates:
ALTER TABLE calendar_rs.cumulative_year_to_dates
  ADD CONSTRAINT cumulative_year_to_dates_base_date_fk FOREIGN KEY (calendar_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);
ALTER TABLE calendar_rs.cumulative_year_to_dates
  ADD CONSTRAINT cumulative_year_to_dates_ytd_date_fk FOREIGN KEY (cumulative_year_to_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);

-- calendar_rs.cumulative_week_to_dates:
ALTER TABLE calendar_rs.cumulative_week_to_dates
  ADD CONSTRAINT cumulative_week_to_dates_base_date_fk FOREIGN KEY (calendar_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);
ALTER TABLE calendar_rs.cumulative_week_to_dates
  ADD CONSTRAINT cumulative_week_to_dates_wtd_date_fk FOREIGN KEY (cumulative_week_to_date)
  REFERENCES calendar_rs.calendar_date (calendar_date);
  
-- generate calendar views
create or replace view calendar_rs.day_of_week_v as select *, 1::integer as day_of_week_qty from calendar_rs.day_of_week;
create or replace view calendar_rs.month_of_year_v as select *, 1::integer as month_of_year_qty from calendar_rs.gregorian_month_of_year;
create or replace view calendar_rs.quarter_of_year_v as select *, 1::integer as quarter_of_year_qty from calendar_rs.gregorian_quarter_of_year;
create or replace view calendar_rs.calendar_year_v as select *, 1::integer as calendar_year_qty from calendar_rs.gregorian_year;
create or replace view calendar_rs.year_quarter_v as select *, 1::integer as year_quarter_qty from calendar_rs.gregorian_year_quarter;
create or replace view calendar_rs.year_month_v as select *, 1::integer as year_month_qty from calendar_rs.gregorian_year_month;
create or replace view calendar_rs.year_week_v as select *, 1::integer as year_week_qty from calendar_rs.year_week;
create or replace view calendar_rs.calendar_date_v as select *, 1::integer as calendar_date_qty from calendar_rs.calendar_date;
create or replace view calendar_rs.calendar_date_hour_min_v as select *, 1::integer as calendar_date_hour_min_qty from calendar_rs.calendar_date_hour_min;
create or replace view calendar_rs.calendar_date_hour_v as select *, 1::integer as calendar_date_hour_qty from calendar_rs.calendar_date_hour;
create or replace view calendar_rs.cumulative_month_to_dates_v as select calendar_date, cumulative_month_to_date from calendar_rs.cumulative_month_to_dates;
create or replace view calendar_rs.cumulative_quarter_to_dates_v as select calendar_date, cumulative_quarter_to_date from calendar_rs.cumulative_quarter_to_dates;
create or replace view calendar_rs.cumulative_year_to_dates_v as select calendar_date, cumulative_year_to_date from calendar_rs.cumulative_year_to_dates;
create or replace view calendar_rs.cumulative_week_to_dates_v as select calendar_date, cumulative_week_to_date from calendar_rs.cumulative_week_to_dates;
