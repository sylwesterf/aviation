----------------------------------------------------
-- STEPS:
-- 0. vacuum tables
-- 1. data validation scripts
--  1.1. cal_load
--  1.2. dim_load
--  1.3. fin_load
--  1.4. t100_load
--  1.5. db1b_load
--  1.6. otp_load
-- 2. smoke-test queries
-- 3. drop staging tables/auxiliary views
----------------------------------------------------

-- 0. vacuum tables
-- cal
VACUUM (ANALYZE, VERBOSE) calendar_pg.hour_of_day;
VACUUM (ANALYZE, VERBOSE) calendar_pg.minute_of_hour;
VACUUM (ANALYZE, VERBOSE) calendar_pg.year_week;
VACUUM (ANALYZE, VERBOSE) calendar_pg.calendar_date;
VACUUM (ANALYZE, VERBOSE) calendar_pg.gregorian_year_month;
VACUUM (ANALYZE, VERBOSE) calendar_pg.day_of_week;
VACUUM (ANALYZE, VERBOSE) calendar_pg.gregorian_quarter_of_year;
VACUUM (ANALYZE, VERBOSE) calendar_pg.gregorian_month_of_year;
VACUUM (ANALYZE, VERBOSE) calendar_pg.gregorian_year_quarter;
VACUUM (ANALYZE, VERBOSE) calendar_pg.gregorian_year;
VACUUM (ANALYZE, VERBOSE) calendar_pg.calendar_date_hour_min;
VACUUM (ANALYZE, VERBOSE) calendar_pg.calendar_date_hour;
VACUUM (ANALYZE, VERBOSE) calendar_pg.cumulative_month_to_dates;
VACUUM (ANALYZE, VERBOSE) calendar_pg.cumulative_quarter_to_dates;
VACUUM (ANALYZE, VERBOSE) calendar_pg.cumulative_year_to_dates;
VACUUM (ANALYZE, VERBOSE) calendar_pg.cumulative_week_to_dates;

-- dim
VACUUM (ANALYZE, VERBOSE) air_oai_dims.aircraft_types;
VACUUM (ANALYZE, VERBOSE) air_oai_dims.airport_history;
VACUUM (ANALYZE, VERBOSE) air_oai_dims.world_areas;
VACUUM (ANALYZE, VERBOSE) air_oai_dims.airline_entities;
VACUUM (ANALYZE, VERBOSE) air_oai_dims.airline_entity_legacy_groups;
VACUUM (ANALYZE, VERBOSE) air_oai_dims.airline_entity_new_groups;

-- fin

-- t100

-- db1b

-- otp


-- null-matrix audit
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
group by 1,2,3,4 order by count(*) desc

select case when airport_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as airport_wac_key_data
     , case when market_city_world_area_key is null then 'null'::char(4) else 'data'::char(4) end as market_city_wac_key_data
     , count(*)
from air_oai_dims.airport_history
group by 1,2 order by count(*) desc;



-- 1.1. cal_load validation
-- 1.1.1. rowcount check
SELECT 'day_of_week_v'                  AS view_name, COUNT(*) AS total_rows FROM calendar_pg.day_of_week_v UNION ALL
SELECT 'month_of_year_v'                AS view_name, COUNT(*) AS total_rows FROM calendar_pg.month_of_year_v UNION ALL
SELECT 'quarter_of_year_v'              AS view_name, COUNT(*) AS total_rows FROM calendar_pg.quarter_of_year_v UNION ALL
SELECT 'calendar_year_v'                AS view_name, COUNT(*) AS total_rows FROM calendar_pg.calendar_year_v UNION ALL
SELECT 'year_quarter_v'                 AS view_name, COUNT(*) AS total_rows FROM calendar_pg.year_quarter_v UNION ALL
SELECT 'year_month_v'                   AS view_name, COUNT(*) AS total_rows FROM calendar_pg.year_month_v UNION ALL
SELECT 'year_week_v'                    AS view_name, COUNT(*) AS total_rows FROM calendar_pg.year_week_v UNION ALL
SELECT 'calendar_date_v'                AS view_name, COUNT(*) AS total_rows FROM calendar_pg.calendar_date_v UNION ALL
SELECT 'calendar_date_hour_v'           AS view_name, COUNT(*) AS total_rows FROM calendar_pg.calendar_date_hour_v UNION ALL
SELECT 'calendar_date_hour_min_v'       AS view_name, COUNT(*) AS total_rows FROM calendar_pg.calendar_date_hour_min_v UNION ALL
SELECT 'cumulative_month_to_dates_v'    AS view_name, COUNT(*) AS total_rows FROM calendar_pg.cumulative_month_to_dates_v UNION ALL
SELECT 'cumulative_quarter_to_dates_v'  AS view_name, COUNT(*) AS total_rows FROM calendar_pg.cumulative_quarter_to_dates_v UNION ALL
SELECT 'cumulative_year_to_dates_v'     AS view_name, COUNT(*) AS total_rows FROM calendar_pg.cumulative_year_to_dates_v UNION ALL
SELECT 'cumulative_week_to_dates_v'     AS view_name, COUNT(*) AS total_rows FROM calendar_pg.cumulative_week_to_dates_v;

-- 1.1.2 data integrity and correctness validation suite
WITH expected_metrics AS (
    SELECT 
        (SELECT COUNT(*) FROM calendar_pg.calendar_year_v) AS total_years,
        (SELECT COUNT(*) FROM calendar_pg.calendar_date_v) AS total_days
),
validation_results AS (

    -- ROW COUNT & CARDINALITY RECONCILIATION
    SELECT 
        'Row Count: day_of_week_v' AS test_name,
        'Exact 7 days per week' AS description,
        ABS((SELECT COUNT(*) FROM calendar_pg.day_of_week_v) - 7) AS violation_count

    UNION ALL

    SELECT 
        'Row Count: month_of_year_v',
        'Exact 12 months per Gregorian year',
        ABS((SELECT COUNT(*) FROM calendar_pg.month_of_year_v) - 12)

    UNION ALL

    SELECT 
        'Row Count: quarter_of_year_v',
        'Exact 4 quarters per year',
        ABS((SELECT COUNT(*) FROM calendar_pg.quarter_of_year_v) - 4)

    UNION ALL

    SELECT 
        'Row Count: year_quarter_v',
        'Total quarters must equal calendar_year_v * 4',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.year_quarter_v) - 
            ((SELECT total_years FROM expected_metrics) * 4)
        )

    UNION ALL

    SELECT 
        'Row Count: year_month_v',
        'Total months must equal calendar_year_v * 12',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.year_month_v) - 
            ((SELECT total_years FROM expected_metrics) * 12)
        )

    UNION ALL

    SELECT 
        'Row Count: year_week_v',
        'Count of year_week_v must equal distinct year_week_nbr in calendar_date_v',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.year_week_v) - 
            (SELECT COUNT(DISTINCT year_week_nbr) FROM calendar_pg.calendar_date_v)
        )

    UNION ALL

    SELECT 
        'Row Count: calendar_date_v',
        'Total days must match day count span between calendar_year_v min/max dates',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_v) - 
            (SELECT (MAX(year_thru_date) - MIN(year_from_date) + 1)::bigint FROM calendar_pg.calendar_year_v)
        )

    UNION ALL

    SELECT 
        'Row Count: calendar_date_hour_v',
        'Hourly resolution must equal calendar_date_v * 24',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_hour_v) - 
            ((SELECT total_days FROM expected_metrics) * 24)
        )

    UNION ALL

    SELECT 
        'Row Count: calendar_date_hour_min_v',
        'Minute resolution must equal calendar_date_v * 1440',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_hour_min_v) - 
            ((SELECT total_days FROM expected_metrics) * 1440)
        )

    UNION ALL

    SELECT 
        'Row Count: cumulative_month_to_dates_v',
        'Count must equal mathematical sum of day-of-month indices across calendar_date_v',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.cumulative_month_to_dates_v) - 
            (SELECT SUM(EXTRACT(DAY FROM calendar_date))::bigint FROM calendar_pg.calendar_date_v)
        )

    UNION ALL

    SELECT 
        'Row Count: cumulative_year_to_dates_v',
        'Count must equal mathematical sum of day-of-year indices across calendar_date_v',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.cumulative_year_to_dates_v) - 
            (SELECT SUM(EXTRACT(DOY FROM calendar_date))::bigint FROM calendar_pg.calendar_date_v)
        )

     UNION ALL

    -- CONTINUITY, GAPS & CARDINALITY (calendar_date_v)
    SELECT 
        'Calendar Date Range Extent' AS test_name,
        'Min and Max dates must span 1900-01-01 through 2090-12-31' AS description,
        CASE 
            WHEN (SELECT MIN(calendar_date) FROM calendar_pg.calendar_date_v) = '1900-01-01'::date
             AND (SELECT MAX(calendar_date) FROM calendar_pg.calendar_date_v) = '2090-12-31'::date 
            THEN 0 ELSE 1 
        END AS violation_count

    UNION ALL

    SELECT 
        'Calendar Date Unbroken Continuity',
        'Contiguous day sequences with zero gaps across calendar_date_v',
        (
            SELECT COUNT(*)
            FROM (
                SELECT calendar_date, 
                       LAG(calendar_date, 1) OVER (ORDER BY calendar_date) AS prev_date
                FROM calendar_pg.calendar_date_v
            ) d
            WHERE prev_date IS NOT NULL 
              AND calendar_date <> prev_date + 1
        )

    UNION ALL

    SELECT 
        'Calendar Date Count Parity',
        'Row count must exactly equal mathematical delta: (MAX - MIN + 1) days',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_v) - 
            (SELECT (MAX(calendar_date) - MIN(calendar_date) + 1) FROM calendar_pg.calendar_date_v)
        )

    -- CALENDAR ENTITY UNIQUENESS & DRILL-DOWN LOGIC
    UNION ALL

    SELECT 
        'Calendar Date PK Uniqueness',
        'Duplicate calendar_date records in calendar_date_v',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT calendar_date 
                FROM calendar_pg.calendar_date_v 
                GROUP BY calendar_date 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Year Month PK Uniqueness',
        'Duplicate year_month_nbr records in year_month_v',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT year_month_nbr 
                FROM calendar_pg.year_month_v 
                GROUP BY year_month_nbr 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Year Quarter PK Uniqueness',
        'Duplicate year_quarter_nbr records in year_quarter_v',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT year_quarter_nbr 
                FROM calendar_pg.year_quarter_v 
                GROUP BY year_quarter_nbr 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Calendar Year PK Uniqueness',
        'Duplicate year_nbr records in calendar_year_v',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT year_nbr 
                FROM calendar_pg.calendar_year_v 
                GROUP BY year_nbr 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Hierarchical Attribute Consistency',
        'Discrepancy between calendar_date parts and joined year_month_v / year_quarter_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.calendar_date_v d
            JOIN calendar_pg.year_month_v ym ON d.year_month_nbr = ym.year_month_nbr
            JOIN calendar_pg.year_quarter_v yq ON ym.year_quarter_nbr = yq.year_quarter_nbr
            WHERE EXTRACT(YEAR FROM d.calendar_date)    <> ym.year_nbr
               OR EXTRACT(MONTH FROM d.calendar_date)   <> ym.month_of_year_nbr
               OR EXTRACT(QUARTER FROM d.calendar_date) <> yq.quarter_of_year_nbr
               OR ym.year_quarter_nbr                   <> d.year_quarter_nbr
               OR ym.year_nbr                           <> d.year_nbr
        )

    UNION ALL

    SELECT 
        'ISO Day of Week Consistency',
        'day_of_week_iso_nbr in calendar_date_v vs EXTRACT(ISODOW)',
        (
            SELECT COUNT(*)
            FROM calendar_pg.calendar_date_v
            WHERE day_of_week_iso_nbr <> EXTRACT(ISODOW FROM calendar_date)::smallint
        )

    UNION ALL

    SELECT 
        'February Boundary Correctness',
        'February must terminate on the 28th (standard) or 29th (leap) in year_month_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.year_month_v ym
            JOIN calendar_pg.calendar_year_v y ON ym.year_nbr = y.year_nbr
            WHERE ym.month_of_year_nbr = 2
              AND (
                  (y.leap_year_ind = 1 AND EXTRACT(DAY FROM ym.year_month_thru_date) <> 29)
                  OR
                  (y.leap_year_ind = 0 AND EXTRACT(DAY FROM ym.year_month_thru_date) <> 28)
              )
        )

    -- CROSS-VIEW REFERENTIAL INTEGRITY (Orphan Checks via Views)
    UNION ALL

    SELECT 
        'View Integrity: calendar_date_v -> year_month_v',
        'Dates in calendar_date_v pointing to missing year_month_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.calendar_date_v d
            LEFT JOIN calendar_pg.year_month_v m ON d.year_month_nbr = m.year_month_nbr
            WHERE m.year_month_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'View Integrity: calendar_date_v -> year_week_v',
        'Dates in calendar_date_v pointing to missing year_week_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.calendar_date_v d
            LEFT JOIN calendar_pg.year_week_v w ON d.year_week_nbr = w.year_week_nbr
            WHERE w.year_week_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'View Integrity: calendar_date_v -> day_of_week_v',
        'Dates in calendar_date_v pointing to missing day_of_week_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.calendar_date_v d
            LEFT JOIN calendar_pg.day_of_week_v dow ON d.day_of_week_iso_nbr = dow.day_of_week_iso_nbr
            WHERE dow.day_of_week_iso_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'View Integrity: year_month_v -> year_quarter_v',
        'Months in year_month_v pointing to missing year_quarter_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.year_month_v ym
            LEFT JOIN calendar_pg.year_quarter_v yq ON ym.year_quarter_nbr = yq.year_quarter_nbr
            WHERE yq.year_quarter_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'View Integrity: year_quarter_v -> calendar_year_v',
        'Quarters in year_quarter_v pointing to missing calendar_year_v',
        (
            SELECT COUNT(*)
            FROM calendar_pg.year_quarter_v yq
            LEFT JOIN calendar_pg.calendar_year_v y ON yq.year_nbr = y.year_nbr
            WHERE y.year_nbr IS NULL
        )

    -- -------------------------------------------------------------------------
    -- 4. CUMULATIVE TRANSFORMATION VIEWS (MTD, QTD, YTD, WTD Bridges)
    -- -------------------------------------------------------------------------
    UNION ALL

    SELECT 
        'MTD View Inverted Boundaries',
        'cumulative_month_to_dates_v has cumulative dates ahead of calendar_date',
        (
            SELECT COUNT(*)
            FROM calendar_pg.cumulative_month_to_dates_v
            WHERE cumulative_month_to_date > calendar_date
        )

    UNION ALL

    SELECT 
        'MTD View Month Isolation',
        'cumulative_month_to_dates_v records crossing month boundaries',
        (
            SELECT COUNT(*)
            FROM calendar_pg.cumulative_month_to_dates_v mtd
            JOIN calendar_pg.calendar_date_v d1 ON mtd.calendar_date = d1.calendar_date
            JOIN calendar_pg.calendar_date_v d2 ON mtd.cumulative_month_to_date = d2.calendar_date
            WHERE d1.year_month_nbr <> d2.year_month_nbr
        )

    UNION ALL

    SELECT 
        'QTD View Quarter Isolation',
        'cumulative_quarter_to_dates_v records crossing quarter boundaries',
        (
            SELECT COUNT(*)
            FROM calendar_pg.cumulative_quarter_to_dates_v qtd
            JOIN calendar_pg.calendar_date_v d1 ON qtd.calendar_date = d1.calendar_date
            JOIN calendar_pg.calendar_date_v d2 ON qtd.cumulative_quarter_to_date = d2.calendar_date
            WHERE d1.year_quarter_nbr <> d2.year_quarter_nbr
        )

    UNION ALL

    SELECT 
        'YTD View Year Isolation',
        'cumulative_year_to_dates_v records crossing year boundaries',
        (
            SELECT COUNT(*)
            FROM calendar_pg.cumulative_year_to_dates_v ytd
            JOIN calendar_pg.calendar_date_v d1 ON ytd.calendar_date = d1.calendar_date
            JOIN calendar_pg.calendar_date_v d2 ON ytd.cumulative_year_to_date = d2.calendar_date
            WHERE d1.year_nbr <> d2.year_nbr
        )

    UNION ALL

    SELECT 
        'WTD View Week Isolation',
        'cumulative_week_to_dates_v records crossing week boundaries',
        (
            SELECT COUNT(*)
            FROM calendar_pg.cumulative_week_to_dates_v wtd
            JOIN calendar_pg.calendar_date_v d1 ON wtd.calendar_date = d1.calendar_date
            JOIN calendar_pg.calendar_date_v d2 ON wtd.cumulative_week_to_date = d2.calendar_date
            WHERE d1.year_week_nbr <> d2.year_week_nbr
        )

    UNION ALL

    SELECT 
        'MTD Accumulator Cardinality Parity',
        'Number of cumulative MTD days per date must match day of month',
        (
            SELECT COUNT(*)
            FROM (
                SELECT calendar_date, COUNT(*) AS mtd_days
                FROM calendar_pg.cumulative_month_to_dates_v
                GROUP BY calendar_date
            ) sub
            WHERE mtd_days <> EXTRACT(DAY FROM calendar_date)::bigint
        )

    -- GRANULARITY VIEW EXPANSIONS (Hourly & Minute Views)
    UNION ALL

    SELECT 
        'Hourly View Multiplier Parity',
        'calendar_date_hour_v count must equal calendar_date_v * 24',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_hour_v) - 
            ((SELECT COUNT(*) FROM calendar_pg.calendar_date_v) * 24)
        )

    UNION ALL

    SELECT 
        'Minute View Multiplier Parity',
        'calendar_date_hour_min_v count must equal calendar_date_v * 1440',
        ABS(
            (SELECT COUNT(*) FROM calendar_pg.calendar_date_hour_min_v) - 
            ((SELECT COUNT(*) FROM calendar_pg.calendar_date_v) * 1440)
        )
)
SELECT 
    test_name,
    CASE 
        WHEN violation_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    violation_count,
    description
FROM validation_results
ORDER BY 
    CASE WHEN violation_count > 0 THEN 0 ELSE 1 END,
    test_name;

-- 1.2. dim_load validation
-- 1.2.1. rowcount check
SELECT 'aircraft_types_v'               AS view_name, COUNT(*) AS total_rows FROM airlines_pg.aircraft_types_v UNION ALL
SELECT 'airport_history_v'              AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airport_history_v UNION ALL
SELECT 'airport_current_v'              AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airport_current_v UNION ALL
SELECT 'world_areas_v'                  AS view_name, COUNT(*) AS total_rows FROM airlines_pg.world_areas_v UNION ALL
SELECT 'airline_entity_legacy_groups_v' AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airline_entity_legacy_groups_v UNION ALL
SELECT 'airline_entity_new_groups_v'    AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airline_entity_new_groups_v UNION ALL
SELECT 'airline_entities_v'             AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airline_entities_v UNION ALL
SELECT 'airline_entities_current_v'     AS view_name, COUNT(*) AS total_rows FROM airlines_pg.airline_entities_current_v;

-- 1.2.2 data integrity and correctness validation suite
WITH validation_results AS (

    -- ROW COUNT RECONCILIATIONS (FDW Source vs Presentation Layer)
    SELECT 
        'Aircraft Types Count Parity' AS test_name,
        'Count discrepancy between FDW and aircraft_types_v' AS description,
        ABS((SELECT COUNT(*) FROM air_oai_dims.aircraft_types_fdw) - 
            (SELECT COUNT(*) FROM airlines_pg.aircraft_types_v)) AS violation_count

    UNION ALL

    SELECT 
        'Airport History Count Parity',
        'Count discrepancy between master_cord_fdw and airport_history_v',
        ABS((SELECT COUNT(*) FROM air_oai_dims.master_cord_fdw) - 
            (SELECT COUNT(*) FROM airlines_pg.airport_history_v))

    UNION ALL

    SELECT 
        'World Areas Count Parity',
        'Count discrepancy between wac_country_state_fdw and world_areas_v',
        ABS((SELECT COUNT(*) FROM air_oai_dims.wac_country_state_fdw) - 
            (SELECT COUNT(*) FROM airlines_pg.world_areas_v))

    UNION ALL

    SELECT 
        'Airline Entities Count Parity',
        'Count discrepancy between carrier_decode_fdw and airline_entities_v',
        ABS((SELECT COUNT(*) FROM air_oai_dims.carrier_decode_fdw) - 
            (SELECT COUNT(*) FROM airlines_pg.airline_entities_v))


    -- SNAPSHOT PARITY (Current/Active Snapshot Filters vs Raw FDW Flags)
    UNION ALL

    SELECT 
        'Airport Current View Snapshot Parity',
        'airport_current_v count does not match master_cord_fdw with AIRPORT_IS_LATEST = 1',
        ABS((SELECT COUNT(*) FROM air_oai_dims.master_cord_fdw WHERE AIRPORT_IS_LATEST = 1) - 
            (SELECT COUNT(*) FROM airlines_pg.airport_current_v))

    UNION ALL

    SELECT 
        'Airline Current View Snapshot Parity',
        'airline_entities_current_v count does not match carrier_decode_fdw with THRU_DATE_SOURCE IS NULL',
        ABS((SELECT COUNT(*) FROM air_oai_dims.carrier_decode_fdw WHERE THRU_DATE_SOURCE IS NULL) - 
            (SELECT COUNT(*) FROM airlines_pg.airline_entities_current_v))


    -- PRIMARY & NATURAL KEY UNIQUENESS (No Duplicates)
    UNION ALL

    SELECT 
        'Aircraft Types PK Uniqueness',
        'Duplicate aircraft_type_oai_nbr detected',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT aircraft_type_oai_nbr 
                FROM airlines_pg.aircraft_types_v 
                GROUP BY aircraft_type_oai_nbr 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Airport History Key Uniqueness',
        'Duplicate airport_history_key detected',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT airport_history_key 
                FROM airlines_pg.airport_history_v 
                GROUP BY airport_history_key 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Airport Current PK Uniqueness',
        'Duplicate airport_oai_id detected in current snapshot',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT airport_oai_id 
                FROM airlines_pg.airport_current_v 
                GROUP BY airport_oai_id 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'World Area Seq ID Uniqueness',
        'Duplicate world_area_oai_seq_id detected',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT world_area_oai_seq_id 
                FROM airlines_pg.world_areas_v 
                GROUP BY world_area_oai_seq_id 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Airline Entity Key Uniqueness',
        'Duplicate airline_entity_key detected',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT airline_entity_key 
                FROM airlines_pg.airline_entities_v 
                GROUP BY airline_entity_key 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)

    UNION ALL

    SELECT 
        'Airline Entities Current PK Uniqueness',
        'Duplicate composite key (carrier + entity) in current snapshot',
        COALESCE((
            SELECT COUNT(*) FROM (
                SELECT airline_oai_code, entity_oai_code 
                FROM airlines_pg.airline_entities_current_v 
                GROUP BY airline_oai_code, entity_oai_code 
                HAVING COUNT(*) > 1
            ) sub
        ), 0)


    -- MISSING SOURCE RECORDS (Anti-Joins FDW -> View)
    UNION ALL

    SELECT 
        'Aircraft Types Missing From FDW',
        'Records present in aircraft_types_fdw but missing in aircraft_types_v',
        (
            SELECT COUNT(*)
            FROM air_oai_dims.aircraft_types_fdw f
            LEFT JOIN airlines_pg.aircraft_types_v v 
                   ON f.AC_TYPEID = v.aircraft_type_oai_nbr
            WHERE v.aircraft_type_oai_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'Airport Missing From FDW',
        'Records present in master_cord_fdw but missing in airport_history_v',
        (
            SELECT COUNT(*)
            FROM air_oai_dims.master_cord_fdw f
            LEFT JOIN airlines_pg.airport_history_v v 
                   ON f.AIRPORT = v.airport_oai_code 
                  AND f.AIRPORT_START_DATE = v.effective_from_date
            WHERE v.airport_history_key IS NULL
        )

    UNION ALL

    SELECT 
        'World Areas Missing From FDW',
        'Records present in wac_country_state_fdw but missing in world_areas_v',
        (
            SELECT COUNT(*)
            FROM air_oai_dims.wac_country_state_fdw f
            LEFT JOIN airlines_pg.world_areas_v v 
                   ON f.WAC_SEQ_ID2 = v.world_area_oai_seq_id
            WHERE v.world_area_oai_seq_id IS NULL
        )

    UNION ALL

    SELECT 
        'Airlines Missing From FDW',
        'Records present in carrier_decode_fdw but missing in airline_entities_v',
        (
            SELECT COUNT(*)
            FROM air_oai_dims.carrier_decode_fdw f
            LEFT JOIN airlines_pg.airline_entities_v v 
                   ON f.CARRIER = v.airline_oai_code 
                  AND f.CARRIER_ENTITY = v.entity_oai_code 
                  AND f.START_DATE_SOURCE = v.source_from_date
            WHERE v.airline_entity_key IS NULL
        )


    -- REFERENTIAL INTEGRITY BETWEEN PRESENTATION VIEWS
    UNION ALL

    SELECT 
        'Airport to World Area FK (airport_world_area_oai_seq_id)',
        'Airports with orphan airport_world_area_oai_seq_id not found in world_areas_v',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airport_history_v a
            LEFT JOIN airlines_pg.world_areas_v w 
                   ON a.airport_world_area_oai_seq_id = w.world_area_oai_seq_id
            WHERE a.airport_world_area_oai_seq_id IS NOT NULL 
              AND w.world_area_oai_seq_id IS NULL
        )

    UNION ALL

    SELECT 
        'Airport to Market City World Area FK (market_city_world_area_oai_seq_id)',
        'Airports with orphan market_city_world_area_oai_seq_id not found in world_areas_v',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airport_history_v a
            LEFT JOIN airlines_pg.world_areas_v w 
                   ON a.market_city_world_area_oai_seq_id = w.world_area_oai_seq_id
            WHERE a.market_city_world_area_oai_seq_id IS NOT NULL 
              AND w.world_area_oai_seq_id IS NULL
        )

    UNION ALL

    SELECT 
        'Airline to World Area FK (world_area_oai_seq_id)',
        'Airlines with orphan world_area_oai_seq_id not found in world_areas_v',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airline_entities_v al
            LEFT JOIN airlines_pg.world_areas_v w 
                   ON al.world_area_oai_seq_id = w.world_area_oai_seq_id
            WHERE al.world_area_oai_seq_id IS NOT NULL 
              AND w.world_area_oai_seq_id IS NULL
        )

    UNION ALL

    SELECT 
        'Airline to Legacy Group FK (airline_old_group_nbr)',
        'Airlines referencing non-existent groups in airline_entity_legacy_groups_v',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airline_entities_v al
            LEFT JOIN airlines_pg.airline_entity_legacy_groups_v lg 
                   ON al.airline_old_group_nbr = lg.airline_old_group_nbr
            WHERE al.airline_old_group_nbr IS NOT NULL 
              AND lg.airline_old_group_nbr IS NULL
        )

    UNION ALL

    SELECT 
        'Airline to New Group FK (airline_new_group_nbr)',
        'Airlines referencing non-existent groups in airline_entity_new_groups_v',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airline_entities_v al
            LEFT JOIN airlines_pg.airline_entity_new_groups_v ng 
                   ON al.airline_new_group_nbr = ng.airline_new_group_nbr
            WHERE al.airline_new_group_nbr IS NOT NULL 
              AND ng.airline_new_group_nbr IS NULL
        )


    -- DATE INTERVAL & HISTORICAL SEQUENCE VALIDITY
    UNION ALL

    SELECT 
        'Airport History Inverted Date Interval',
        'Airports where effective_from_date > effective_thru_date',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airport_history_v
            WHERE effective_thru_date IS NOT NULL 
              AND effective_from_date > effective_thru_date
        )

    UNION ALL

    SELECT 
        'World Areas Inverted Date Interval',
        'World areas where effective_from_date > effective_thru_date',
        (
            SELECT COUNT(*)
            FROM airlines_pg.world_areas_v
            WHERE effective_thru_date IS NOT NULL 
              AND effective_from_date > effective_thru_date
        )

    UNION ALL

    SELECT 
        'Airline Entities Inverted Date Interval',
        'Airline entities where source_from_date > source_thru_date',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airline_entities_v
            WHERE source_thru_date IS NOT NULL 
              AND source_from_date > source_thru_date
        )

    UNION ALL

    SELECT 
        'Aircraft Types Inverted Date Interval',
        'Aircraft types where aircraft_type_from_date > aircraft_type_thru_date',
        (
            SELECT COUNT(*)
            FROM airlines_pg.aircraft_types_v
            WHERE aircraft_type_thru_date IS NOT NULL 
              AND aircraft_type_from_date > aircraft_type_thru_date
        )

    UNION ALL

    SELECT 
        'Airport History Overlapping Intervals',
        'Temporal collisions where date ranges overlap for the same airport_oai_id',
        COALESCE((
            SELECT COUNT(*)
            FROM airlines_pg.airport_history_v a1
            INNER JOIN airlines_pg.airport_history_v a2
                    ON a1.airport_oai_id = a2.airport_oai_id
                   AND a1.airport_history_key <> a2.airport_history_key
                   AND a1.effective_from_date < COALESCE(a2.effective_thru_date, '9999-12-31'::date)
                   AND COALESCE(a1.effective_thru_date, '9999-12-31'::date) > a2.effective_from_date
                   AND a1.effective_from_date >= a2.effective_from_date
        ), 0)

    UNION ALL

    SELECT 
        'Airline Entities Overlapping Intervals',
        'Temporal collisions where date ranges overlap for the same carrier + entity',
        COALESCE((
            SELECT COUNT(*)
            FROM airlines_pg.airline_entities_v a1
            INNER JOIN airlines_pg.airline_entities_v a2
                    ON a1.airline_oai_code = a2.airline_oai_code
                   AND a1.entity_oai_code = a2.entity_oai_code
                   AND a1.airline_entity_key <> a2.airline_entity_key
                   AND a1.source_from_date < COALESCE(a2.source_thru_date, '9999-12-31'::date)
                   AND COALESCE(a1.source_thru_date, '9999-12-31'::date) > a2.source_from_date
                   AND a1.source_from_date >= a2.source_from_date
        ), 0)


    -- VALUE DISCREPANCIES & DOMAIN SANITY CHECKS
    UNION ALL

    SELECT 
        'Airport Attributes Discrepancy',
        'Field-level value mismatch between master_cord_fdw and airport_history_v',
        (
            SELECT COUNT(*)
            FROM air_oai_dims.master_cord_fdw f
            INNER JOIN airlines_pg.airport_history_v v 
                    ON f.AIRPORT = v.airport_oai_code 
                   AND f.AIRPORT_START_DATE = v.effective_from_date
            WHERE f.DISPLAY_AIRPORT_NAME IS DISTINCT FROM v.airport_display_name
               OR f.LATITUDE             IS DISTINCT FROM v.latitude_decimal_nbr
               OR f.LONGITUDE            IS DISTINCT FROM v.longitude_decimal_nbr
               OR (CASE WHEN LENGTH(f.UTC_LOCAL_TIME_VARIATION) = 0 THEN NULL ELSE f.UTC_LOCAL_TIME_VARIATION END) 
                  IS DISTINCT FROM v.utc_local_time_variation
        )

    UNION ALL

    SELECT 
        'Coordinate Boundary Violations',
        'Latitude outside [-90, 90] or Longitude outside [-180, 180]',
        (
            SELECT COUNT(*)
            FROM airlines_pg.airport_history_v
            WHERE (latitude_decimal_nbr IS NOT NULL AND (latitude_decimal_nbr < -90.0 OR latitude_decimal_nbr > 90.0))
               OR (longitude_decimal_nbr IS NOT NULL AND (longitude_decimal_nbr < -180.0 OR longitude_decimal_nbr > 180.0))
        )
)
SELECT 
    test_name,
    CASE 
        WHEN violation_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    violation_count,
    description
FROM validation_results
ORDER BY 
    CASE WHEN violation_count > 0 THEN 0 ELSE 1 END,
    test_name;


-- 1.3. fin_load

-- 1.4. t100_load

-- 1.5. db1b_load

-- 1.6. otp_load





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
---------------------------------------------------------
----------------------- db1b -----------------------------
---------------------------------------------------------

-- 6. Validation
--TODO
select year_nbr, quarter_nbr, count(*) from air_oai_facts.airfare_survey_ticket_fdw group by 1,2;
select year_quarter_start_date, count(*) from air_oai_facts.airfare_survey_itinerary group by 1 order by 1 desc;
-- select itinerary_oai_id, flight_pass_seq, count(*) from airlines_pg.airfare_survey_coupon_v group by 1,2 having count(*) > 1 order by count(*) desc;
-- select market_oai_id, count(*) from airlines_pg.airfare_survey_market_v group by 1 having count(*) > 1 order by count(*) desc;

-- 7. Clean-up
DROP FOREIGN TABLE IF EXISTS air_oai_facts.airfare_survey_ticket_fdw;
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_ticket_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_facts.airfare_survey_coupon_fdw;
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_coupon_fdw;
DROP FOREIGN TABLE IF EXISTS air_oai_facts.airfare_survey_market_fdw;
DROP TABLE IF EXISTS air_oai_facts.airfare_survey_market_fdw;


-- 2. analytical smoke-test queries

-- cal
-- drill down hierarchy aggregation
SELECT 
    y.year_nbr,
    y.leap_year_ind,
    yq.quarter_of_year_nbr,
    ym.month_of_year_nbr,
    COUNT(d.calendar_date)                  AS day_count,
    MIN(d.calendar_date)                    AS month_start,
    MAX(d.calendar_date)                    AS month_end,
    COUNT(DISTINCT d.year_week_nbr)         AS distinct_weeks_spanned
FROM calendar_pg.calendar_date_v d
JOIN calendar_pg.year_month_v ym 
  ON d.year_month_nbr = ym.year_month_nbr
JOIN calendar_pg.year_quarter_v yq 
  ON ym.year_quarter_nbr = yq.year_quarter_nbr
JOIN calendar_pg.calendar_year_v y 
  ON yq.year_nbr = y.year_nbr
WHERE y.year_nbr IN (2020, 2023, 2024) -- Checks recent leap (2020, 2024) and non-leap (2023)
GROUP BY 
    y.year_nbr,
    y.leap_year_ind,
    yq.quarter_of_year_nbr,
    ym.month_of_year_nbr
ORDER BY y.year_nbr, ym.month_of_year_nbr;

-- day of week distribution sanity test
SELECT 
    dow.day_of_week_iso_nbr,
    dow.day_of_week_abbr,
    dow.day_of_week_name_eng,
    COUNT(d.calendar_date)                  AS total_occurrences,
    MIN(d.calendar_date)                    AS first_instance,
    MAX(d.calendar_date)                    AS last_instance
FROM calendar_pg.calendar_date_v d
JOIN calendar_pg.day_of_week_v dow 
  ON d.day_of_week_iso_nbr = dow.day_of_week_iso_nbr
GROUP BY 
    dow.day_of_week_iso_nbr,
    dow.day_of_week_abbr,
    dow.day_of_week_name_eng
ORDER BY dow.day_of_week_iso_nbr;

-- dim
-- closest Airport Pairs
WITH airport_geo AS (
    SELECT 
        airport_oai_id,
        airport_oai_code,
        airport_display_name,
        city_full_display_name,
        latitude_decimal_nbr,
        longitude_decimal_nbr,
        ST_SetSRID(ST_MakePoint(longitude_decimal_nbr, latitude_decimal_nbr), 4326)::geography AS geom_geog
    FROM airlines_pg.airport_current_v
    WHERE airport_closed_ind = 0
      AND latitude_decimal_nbr IS NOT NULL 
      AND longitude_decimal_nbr IS NOT NULL
)
SELECT 
    a1.airport_oai_code AS airport_1_code,
    a1.airport_display_name AS airport_1_name,
    a1.city_full_display_name AS airport_1_city,
    a2.airport_oai_code AS airport_2_code,
    a2.airport_display_name AS airport_2_name,
    a2.city_full_display_name AS airport_2_city,
    ROUND((ST_Distance(a1.geom_geog, a2.geom_geog) / 1000.0)::numeric, 3) AS distance_km,
    ROUND((ST_Distance(a1.geom_geog, a2.geom_geog) * 0.000621371)::numeric, 3) AS distance_miles
FROM airport_geo a1
JOIN airport_geo a2 
  ON a1.airport_oai_id < a2.airport_oai_id
WHERE ST_Distance(a1.geom_geog, a2.geom_geog) > 100 -- Filters out co-located duplicate coordinates / same airfield (< 100m)
ORDER BY ST_Distance(a1.geom_geog, a2.geom_geog) ASC
LIMIT 10;

-- Full Hierarchy Rollup (Airport -> Market -> Region -> Sovereign State)
SELECT 
    a.airport_oai_code,
    a.airport_display_name,
    a.city_full_display_name,
    a.time_zone_name,
    w_phys.world_area_name       AS airport_wac_name,
    w_phys.subdivision_name      AS airport_state_name,
    w_phys.country_short_name    AS airport_country_name,
    w_phys.sovereign_country_name AS airport_sovereignty,
    a.market_city_full_display_name,
    w_mkt.world_area_name        AS market_wac_name,
    w_mkt.world_region_name      AS market_world_region
FROM airlines_pg.airport_current_v a
LEFT JOIN airlines_pg.world_areas_v w_phys 
       ON a.airport_world_area_oai_seq_id = w_phys.world_area_oai_seq_id
LEFT JOIN airlines_pg.world_areas_v w_mkt 
       ON a.market_city_world_area_oai_seq_id = w_mkt.world_area_oai_seq_id
WHERE a.airport_closed_ind = 0
ORDER BY w_phys.country_short_name NULLS LAST, a.airport_display_name
LIMIT 50;

-- Airport Name & Code Reallocations - Timeline
SELECT 
    airport_oai_id,
    airport_oai_code,
    airport_display_name,
    city_full_display_name,
    effective_from_date,
    COALESCE(effective_thru_date, '9999-12-31'::date) AS effective_thru_date,
    airport_closed_ind,
    airport_latest_ind,
    ROW_NUMBER() OVER (PARTITION BY airport_oai_id ORDER BY effective_from_date) AS version_seq,
    COUNT(*) OVER (PARTITION BY airport_oai_id) AS total_historical_versions
FROM airlines_pg.airport_history_v
WHERE airport_oai_id IN (
    -- Filter for airports that have 3 or more lifecycle mutations
    SELECT airport_oai_id 
    FROM airlines_pg.airport_history_v 
    GROUP BY airport_oai_id 
    HAVING COUNT(*) >= 3
)
ORDER BY airport_oai_id, effective_from_date;


-- Carrier Group Classification & Operating Region
SELECT 
    COALESCE(al.operating_region_code, 'UNASSIGNED') AS operating_region,
    COALESCE(ng.airline_new_group_name, 'Unknown New Group') AS modern_group,
    COUNT(DISTINCT al.airline_usdot_id) AS total_dot_carriers,
    COUNT(DISTINCT al.airline_oai_code) AS total_iata_codes,
    STRING_AGG(DISTINCT al.airline_oai_code, ', ' ORDER BY al.airline_oai_code) AS sample_carriers
FROM airlines_pg.airline_entities_current_v al
LEFT JOIN airlines_pg.airline_entity_new_groups_v ng 
       ON al.airline_new_group_nbr = ng.airline_new_group_nbr
GROUP BY 
    al.operating_region_code,
    ng.airline_new_group_name
ORDER BY operating_region, total_dot_carriers DESC;

-- Number of Airports by region
SELECT 
    w.world_region_name,
    COUNT(DISTINCT a.airport_oai_id) AS total_airports,
    COUNT(DISTINCT CASE WHEN a.airport_closed_ind = 0 THEN a.airport_oai_id END) AS active_airports
FROM airlines_pg.airport_current_v a
JOIN airlines_pg.world_areas_v w 
  ON a.airport_world_area_oai_seq_id = w.world_area_oai_seq_id
GROUP BY w.world_region_name
order by 2 desc

-- Aircraft Model Inventory Profile & Fleet Lifespan
SELECT 
   ac.manufacturer_name AS manufacturer,
    COUNT(DISTINCT ac.aircraft_type_oai_nbr) AS distinct_type_variants,
    MIN(ac.aircraft_type_from_date) AS earliest_type_introduction,
    MAX(COALESCE(ac.aircraft_type_thru_date, CURRENT_DATE)) AS latest_effective_period,
    ROUND(AVG(
        EXTRACT(YEAR FROM COALESCE(ac.aircraft_type_thru_date, CURRENT_DATE)) - 
        EXTRACT(YEAR FROM ac.aircraft_type_from_date)
    )::numeric, 1) AS avg_model_effective_years,
    COUNT(CASE WHEN ac.aircraft_type_thru_date IS NULL THEN 1 END) AS active_model_variants
FROM airlines_pg.aircraft_types_v ac
GROUP BY ac.manufacturer_name
HAVING COUNT(DISTINCT ac.aircraft_type_oai_nbr) > 1
ORDER BY distinct_type_variants DESC;

-- Full denormalization - Unified snapshot connecting active airports and local airlines to their geographic regions, regulatory tiers, and aircraft types
SELECT 
    -- Airport Current Snapshot
    apc.airport_oai_id,
    apc.airport_oai_code,
    apc.airport_display_name,
    apc.city_full_display_name,
    apc.time_zone_name                      AS airport_time_zone,
    apc.utc_local_time_variation,
    apc.latitude_decimal_nbr,
    apc.longitude_decimal_nbr,
    apc.airport_closed_ind,
    -- Airport Physical Geopolitical Hierarchy (World Areas)
    w_phys.world_area_oai_id                AS airport_physical_wac_id,
    w_phys.world_area_name                  AS airport_physical_wac_name,
    w_phys.subdivision_name                 AS airport_state_name,
    w_phys.subdivision_iso_code             AS airport_state_code,
    w_phys.country_short_name               AS airport_country_name,
    w_phys.country_iso_code                 AS airport_country_iso,
    w_phys.sovereign_country_name           AS airport_sovereignty,
    -- Airport Market Geopolitical Hierarchy (World Areas)
    apc.market_city_oai_id,
    apc.market_city_full_display_name,
    w_mkt.world_area_oai_id                 AS market_wac_id,
    w_mkt.world_area_name                   AS market_wac_name,
    w_mkt.world_region_name                 AS market_world_region,
    -- Active Airline Entity in Same World Area
    aec.airline_usdot_id,
    aec.airline_oai_code,
    aec.entity_oai_code,
    aec.airline_name                        AS active_airline_name,
    aec.operating_region_code,
    -- Carrier Regulatory Groups (Legacy and Modern)
    alg.airline_old_group_nbr,
    alg.airline_old_group_name,
    ang.airline_new_group_nbr,
    ang.airline_new_group_name,
    -- Carrier Geopolitical Hierarchy (World Areas)
    w_air.world_area_oai_id                 AS carrier_wac_id,
    w_air.world_area_name                   AS carrier_wac_name,
    w_air.country_short_name                AS carrier_country_name,
    w_air.country_iso_code                  AS carrier_country_iso,
    w_air.sovereign_country_name            AS carrier_sovereignty,
    -- Active Aircraft Catalog
    act.aircraft_type_oai_nbr,
    act.aircraft_type_brief_name,
    act.aircraft_type_long_name,
    act.manufacturer_name                   AS aircraft_manufacturer,
    act.aircraft_group_oai_nbr,
    act.aircraft_oai_type
FROM airlines_pg.airport_current_v apc
-- Airport physical location resolved via sequence ID
LEFT JOIN airlines_pg.world_areas_v w_phys 
       ON apc.airport_world_area_oai_seq_id = w_phys.world_area_oai_seq_id
-- Airport city market location resolved via sequence ID
LEFT JOIN airlines_pg.world_areas_v w_mkt 
       ON apc.market_city_world_area_oai_seq_id = w_mkt.world_area_oai_seq_id
-- Active airlines in the same World Area Code
LEFT JOIN airlines_pg.airline_entities_current_v aec 
       ON apc.airport_world_area_oai_id = aec.world_area_oai_id
-- Regulatory carrier groups
LEFT JOIN airlines_pg.airline_entity_legacy_groups_v alg 
       ON aec.airline_old_group_nbr = alg.airline_old_group_nbr
LEFT JOIN airlines_pg.airline_entity_new_groups_v ang 
       ON aec.airline_new_group_nbr = ang.airline_new_group_nbr
-- Carrier home country / WAC metadata (using world_area_oai_id + world_area_latest_ind = 1)
LEFT JOIN airlines_pg.world_areas_v w_air 
       ON aec.world_area_oai_id = w_air.world_area_oai_id
      AND w_air.world_area_latest_ind = 1
-- Active aircraft type reference catalog
LEFT JOIN airlines_pg.aircraft_types_v act 
       ON (act.aircraft_type_thru_date IS NULL OR act.aircraft_type_thru_date > CURRENT_DATE)
WHERE apc.airport_closed_ind = 0
LIMIT 100;

-- unit test 1
select airline_entity_id, airline_name, operating_region_code
from airlines_pg.airline_entities_v
where airline_oai_code = 'DL';

-- unit test 2
select airport_history_id, airport_display_name, country_name,  effective_from_date, effective_thru_date, airport_latest_ind
from airlines_pg.airport_history_v 
where airport_oai_code = 'NRT'
order by effective_from_date;

-- fin

-- t100

-- db1b

-- otp



-- 3. drop staging tables/auxiliary views
-- cal
drop schema if exists cal_gen cascade;

-- dim
DROP TABLE IF EXISTS air_oai_dims.aircraft_types_fdw;
DROP TABLE IF EXISTS air_oai_dims.wac_country_state_fdw;
DROP TABLE IF EXISTS air_oai_dims.carrier_decode_fdw;
DROP TABLE IF EXISTS air_oai_dims.master_cord_fdw;
DROP TABLE IF EXISTS air_oai_dims.aircraft_type_groups_fdw;
DROP TABLE IF EXISTS air_oai_dims.airline_entity_legacy_groups_fdw;
DROP TABLE IF EXISTS air_oai_dims.airline_entity_new_groups_fdw;

-- fin

-- t100

-- db1b

-- otp