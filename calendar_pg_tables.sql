-- create calendar schema
create schema if not exists calendar_pg;

-- create calendar tables based on base views and start/end year
-- set calendar start and end years as variables
DO $$ 
DECLARE
	start_year INT = 1900;
	end_year INT = 2090;
BEGIN 
	create or replace table calendar_pg.day_of_week as select * from cal_gen.make_day_of_week_v;
	create or replace table calendar_pg.gregorian_month_of_year as select * from cal_gen.make_gregorian_month_of_year_v;
	create or replace table calendar_pg.gregorian_quarter_of_year as select * from cal_gen.make_gregorian_quarter_of_year_v;
	create or replace table calendar_pg.gregorian_year as select * from cal_gen.make_gregorian_year_v where year_nbr between start_year and end_year; 
	create or replace table calendar_pg.gregorian_year_quarter as select * from cal_gen.make_gregorian_year_quarter_v where year_nbr between start_year and end_year; 
	create or replace table calendar_pg.gregorian_year_month as select * from cal_gen.make_gregorian_year_month_v where year_nbr between start_year and end_year; 
	create or replace table calendar_pg.year_week as select * from cal_gen.make_year_week_v where year_nbr between start_year and end_year; 
	create or replace table calendar_pg.calendar_date as select * from cal_gen.make_calendar_date_v where year_nbr between start_year and end_year; 
	create or replace table calendar_pg.hour_of_day_alpha as select * from cal_gen.make_hour_of_day_v;
	create or replace table calendar_pg.minute_of_hour_alpha as select * from cal_gen.make_minute_of_hour_v;
	create or replace table calendar_pg.calendar_date_hour_min as select * from cal_gen.make_calendar_date_hour_min_v where date_part('year', calendar_date) between start_year and end_year; 
	create or replace table calendar_pg.calendar_date_hour as select * from cal_gen.make_calendar_date_hour_v where date_part('year', calendar_date) between start_year and end_year; 
END $$;

-- add comments to calendar tables
-- calendar_pg.day_of_week
COMMENT ON TABLE calendar_pg.day_of_week IS 'Monday is the first day of the working week, ISO 2105/8601.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_common_nbr IS 'This number begins with Sunday as 1, and is in common usage.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_pgsql_nbr IS 'PostgreSQL functions list Sunday as 0, and Saturday as 6.';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_abbr IS 'Standard abbreviation of the day of week (in English).';
COMMENT ON COLUMN calendar_pg.day_of_week.day_of_week_name_eng IS 'The full name of the day of the week (in English).';

-- calendar_pg.gregorian_month_of_year
COMMENT ON TABLE calendar_pg.gregorian_month_of_year IS 'Gregorian Years have 12 months, and have since it evolved from Roman years.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.standard_year_day_qty IS 'The number of Days within this month for a Standard Year.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.leap_year_day_qty IS 'The number of days within this month during a Leap Year.';
COMMENT ON COLUMN calendar_pg.gregorian_month_of_year.month_of_year_name IS 'The word which identifies this month.';

-- calendar_pg.gregorian_quarter_of_year
COMMENT ON TABLE calendar_pg.gregorian_quarter_of_year IS 'A quarter is a standard calendar_pg.interval consisting of three calendar_pg.months, and generally analagous to a "season", which is in keeping with the agricultural purpose of the calendar_pg.';

-- calendar_pg.gregorian_year
COMMENT ON TABLE calendar_pg.gregorian_year IS 'A year represents the number of orbits by the earth around the sun within the Common Era (CE), defined by Pope Gregory XIII in October 1582.';
COMMENT ON COLUMN calendar_pg.gregorian_year.year_nbr IS 'A modern year is a four digit number.';

-- calendar_pg.gregorian_year_quarter
COMMENT ON TABLE calendar_pg.gregorian_year_quarter IS 'This is the natural list of quarters within a specific year.';
COMMENT ON COLUMN calendar_pg.gregorian_year_quarter.year_nbr IS 'The year containing this year-quarter.';

-- calendar_pg.gregorian_year_month
COMMENT ON TABLE calendar_pg.gregorian_year_month IS 'This is the natural list of months within a specific year.';

-- calendar_pg.year_week
COMMENT ON TABLE calendar_pg.year_week IS 'This is the nautral list of weeks within a specific year.';
COMMENT ON COLUMN calendar_pg.year_week.year_week_nbr IS 'The numbered weeks within a year.';
COMMENT ON COLUMN calendar_pg.year_week.year_nbr IS 'The year that contains this week.';

-- calendar_pg.calendar_date
COMMENT ON TABLE calendar_pg.calendar_date IS 'A calendar day represents the spin of the earth on its axis, providing a day and night cycle.';
COMMENT ON COLUMN calendar_pg.calendar_date.day_of_week_iso_nbr IS 'ISO defines Monday as the first day of the week.';
COMMENT ON COLUMN calendar_pg.calendar_date.year_week_nbr IS 'Weeks always have seven days, and each is assigned a number within a Year; week 1 contains January 1 for that year.';

-- calendar_pg.hour_of_day
COMMENT ON TABLE calendar_pg.hour_of_day IS 'Our 24-hour day comes from the ancient Egyptians who divided day-time into 10 hours they measured with devices such as shadow clocks, and added a twilight hour at the beginning and another one at the end of the day-time.';
COMMENT ON COLUMN calendar_pg.hour_of_day.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

-- calendar_pg.minute_of_hour
COMMENT ON TABLE calendar_pg.minute_of_hour IS 'The division of the hour into 60 minutes and of the minute into 60 seconds comes from ancient civilizations -  Babylonians, Sumerians and Egyptians - who had different numbering systems; base 12 (duodecimal) and base 60 (sexagesimal) for mathematics.';

-- calendar_pg.calendar_date_hour_min 
COMMENT ON TABLE calendar_pg.calendar_date_hour_min IS 'A comprehensive timeline with minute-level granularity made by combining calendar dates, hours of the day, and minutes of the hour.';
COMMENT ON COLUMN calendar_pg.calendar_date_hour_min.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';

-- calendar_pg.calendar_date_hour
COMMENT ON TABLE calendar_pg.calendar_date_hour IS 'A series of timestamps with hourly granularity by combining calendar dates and hours of the day';
COMMENT ON COLUMN calendar_pg.calendar_date_hour.period_code IS 'This specifies a subdivision within a day, such as morning, afternoon, evening or night.';


-- add keys to calendar tables
-- primary keys
ALTER TABLE calendar_pg.day_of_week ADD CONSTRAINT day_of_week_pk  PRIMARY KEY (day_of_week_iso_nbr);
ALTER TABLE calendar_pg.gregorian_month_of_year ADD CONSTRAINT gregorian_month_of_year_pk  PRIMARY KEY (month_of_year_nbr);
ALTER TABLE calendar_pg.gregorian_quarter_of_year ADD CONSTRAINT gregorian_quarter_of_year_pk  PRIMARY KEY (quarter_of_year_nbr);
ALTER TABLE calendar_pg.gregorian_year ADD CONSTRAINT gregorian_year_pk  PRIMARY KEY (year_nbr);
ALTER TABLE calendar_pg.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_pk  PRIMARY KEY (year_quarter_nbr);
ALTER TABLE calendar_pg.gregorian_year_month ADD CONSTRAINT gregorian_year_month_pk  PRIMARY KEY (year_month_nbr);
ALTER TABLE calendar_pg.year_week ADD CONSTRAINT year_week_pk  PRIMARY KEY (year_week_nbr);
ALTER TABLE calendar_pg.calendar_date ADD CONSTRAINT calendar_date_pk  PRIMARY KEY (calendar_date);
ALTER TABLE calendar_pg.hour_of_day ADD CONSTRAINT hour_of_day_pk  PRIMARY KEY (hour_of_day_nbr);
ALTER TABLE calendar_pg.minute_of_hour ADD CONSTRAINT minute_of_hour_pk  PRIMARY KEY (minute_of_hour_nbr);

-- add indexes for calendar_pg tables
CREATE UNIQUE INDEX gregorian_month_of_year_ak1 ON calendar_pg.gregorian_month_of_year (month_of_year_code);
CREATE UNIQUE INDEX gregorian_year_quarter_ak1 ON calendar_pg.gregorian_year_quarter (year_quarter_standard_code);
CREATE UNIQUE INDEX year_week_ak1 ON calendar_pg.year_week (year_nbr, week_of_year_nbr);
CREATE INDEX calendar_date_year_week_if1 ON calendar_pg.calendar_date (year_week_nbr);
CREATE INDEX calendar_date_year_month_if2 ON calendar_pg.calendar_date (year_month_nbr);
CREATE INDEX calendar_date_day_of_week_if3 ON calendar_pg.calendar_date (day_of_week_iso_nbr);
CREATE INDEX gregorian_month_of_year_quarter_of_year_if1 ON calendar_pg.gregorian_month_of_year (quarter_of_year_nbr);
CREATE INDEX gregorian_year_month_year_quarter_if1 ON calendar_pg.gregorian_year_month (year_quarter_nbr);
CREATE INDEX gregorian_year_month_of_year_if1 ON calendar_pg.gregorian_year_month (month_of_year_nbr);
CREATE INDEX gregorian_year_quarter_year_if1 ON calendar_pg.gregorian_year_quarter (year_nbr);
CREATE INDEX gregorian_year_quarter_of_year_if2 ON calendar_pg.gregorian_year_quarter (quarter_of_year_nbr);
CREATE INDEX year_week_if1 ON calendar_pg.year_week (year_nbr);

-- define foreign keys to calendar_pg tables
ALTER TABLE calendar_pg.calendar_date ADD CONSTRAINT calendar_date_year_week_fk 
FOREIGN KEY (year_week_nbr) REFERENCES calendar_pg.year_week (year_week_nbr);
ALTER TABLE calendar_pg.calendar_date ADD CONSTRAINT calendar_date_year_month_fk 
FOREIGN KEY (year_month_nbr) REFERENCES calendar_pg.gregorian_year_month (year_month_nbr);
ALTER TABLE calendar_pg.calendar_date ADD CONSTRAINT calendar_date_day_of_week_fk 
FOREIGN KEY (day_of_week_iso_nbr) REFERENCES calendar_pg.day_of_week (day_of_week_iso_nbr);
ALTER TABLE calendar_pg.gregorian_month_of_year ADD CONSTRAINT gregorian_month_of_year_quarter_of_year_fk  
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_pg.gregorian_quarter_of_year (quarter_of_year_nbr);
ALTER TABLE calendar_pg.gregorian_year_month ADD CONSTRAINT gregorian_year_month_year_quarter_fk 
FOREIGN KEY (year_quarter_nbr) REFERENCES calendar_pg.gregorian_year_quarter (year_quarter_nbr);
ALTER TABLE calendar_pg.gregorian_year_month ADD CONSTRAINT gregorian_year_month_month_of_year_fk 
FOREIGN KEY (month_of_year_nbr) REFERENCES calendar_pg.gregorian_month_of_year (month_of_year_nbr);
ALTER TABLE calendar_pg.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_year_fk 
FOREIGN KEY (year_nbr) REFERENCES calendar_pg.gregorian_year (year_nbr);
ALTER TABLE calendar_pg.gregorian_year_quarter ADD CONSTRAINT gregorian_year_quarter_quarter_of_year_fk 
FOREIGN KEY (quarter_of_year_nbr) REFERENCES calendar_pg.gregorian_quarter_of_year (quarter_of_year_nbr);
ALTER TABLE calendar_pg.year_week ADD CONSTRAINT year_week_gregorian_year_fk  
FOREIGN KEY (year_nbr) REFERENCES calendar_pg.gregorian_year (year_nbr);
alter table calendar_pg.calendar_date_hour_min  add constraint calendar_date_hour_min_calendar_date_fk 
foreign key (calendar_date) references calendar_pg.calendar_date (calendar_date);
alter table calendar_pg.calendar_date_hour  add constraint calendar_date_hour_calendar_date_fk 
foreign key (calendar_date) references calendar_pg.calendar_date (calendar_date);

-- generate transformation tables
-- MTD
create or replace table calendar_pg.cumulative_month_to_dates as
select d.calendar_date, x.calendar_date as cumulative_month_to_date
from calendar_pg.calendar_date d join calendar_pg.calendar_date x 
  on d.year_month_nbr = x.year_month_nbr
where x.calendar_date <= d.calendar_date
and x.calendar_date <= (select max(calendar_date) from calendar_pg.calendar_date)
order by d.calendar_date, x.calendar_date;

-- QTD 
create or replace table calendar_pg.cumulative_quarter_to_dates as
select d.calendar_date, x.calendar_date as cumulative_quarter_to_date
from calendar_pg.calendar_date d join calendar_pg.calendar_date x 
  on d.year_quarter_nbr = x.year_quarter_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- YTD
create or replace table calendar_pg.cumulative_year_to_dates as
select d.calendar_date, x.calendar_date as cumulative_year_to_date
from calendar_pg.calendar_date d join calendar_pg.calendar_date x 
  on d.year_nbr = x.year_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- WTD
create or replace table calendar_pg.cumulative_week_to_dates as
select d.calendar_date, x.calendar_date as cumulative_week_to_date
from calendar_pg.calendar_date d join calendar_pg.calendar_date x 
  on d.year_week_nbr = x.year_week_nbr
where x.calendar_date <= d.calendar_date
order by d.calendar_date, x.calendar_date;

-- add comments to transformation tables
comment on table calendar_pg.cumulative_year_to_dates is 'Time transformation for MSTR, relates calendar_date to Year-To-Date (YTD) cumulative dates.';
comment on table calendar_pg.cumulative_quarter_to_dates is 'Time transformation for MSTR, relates calendar_date to Quarter-To-Date (QTD) cumulative dates.';
comment on table calendar_pg.cumulative_month_to_dates is 'Time transformation for MSTR, relates calendar_date to Month-To-Date (MTD) cumulative dates.';
comment on table calendar_pg.cumulative_week_to_dates is 'Time transformation for MSTR, relates calendar_date to Week-To-Date (WTD) cumulative dates.';

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

-- generate calendar_pg views
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

-- END of script
