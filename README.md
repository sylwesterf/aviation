# aviation
Aviation database, all flavors and tools

Leveraging our 30 year history, Strategy writes the best automated SQL for all analytical databases, Cloud datawarehouses and data lakes included. Ongoing investments data gateways show that MSTR continues the strategy to work with all major database technologies, and continues to support nearly all available options. Please checkout the MSTR Data Gateway portal for Supported and Certified options: 

https://www2.microstrategy.com/producthelp/Current/Gateway_Connections/WebHelp/Lang_1033/Content/home.htm

Of these many options for MSTR customers, we have selected a few that are popular choices for our customers, as we see some of them migrate to a new data platform to support their Business Intelligence and Analytics workloads.

* We started off with organizing the data in PostgreSQL, due to the excellent spatial and data integration capabilities of this tool.
* We have already started to use Snowflake as an excellent Cloud DWH, and have plans expand this.
* We also want to build an example using Databricks, possibly using the raw CSV data in AWS S3, or better yet Parquet formatted enriched data.
* We plan to build these workloads in AWS Redshift, which is only a hop, skip and jump from our original PostgreSQL design.
* Also, we plan to build on Google BigQuery, as another excellent Cloud DWH option, but which has its own unique technology.
* As time permits, we might try some advanced options, like a graph database (Neo4J?)

Vanilla PostgreSQL execution order (`postgres_cursor` branch):

Prerequisites: PostgreSQL 14+ with `postgis` and `pg_analytics` installed; set `shared_preload_libraries = 'pg_analytics'` in `postgresql.conf` and restart. Configure AWS credentials for S3 reads. Loads use the `parquet_wrapper` FDW (pg_analytics’s single DuckDB wrapper—it handles **CSV and Parquet** via `OPTIONS (files 's3://.../file.csv')` or `.parquet`). Staging: `CREATE FOREIGN TABLE <name>_fdw () SERVER pg_analytics_s3 OPTIONS (files 's3://...')`; transforms read from `<name>_fdw`.

Alternative local loads: commented `mstr_psql` + `COPY` + heap `CREATE TABLE ..._fdw` in each `*_load.sql` script (use instead of the pg_analytics block). Set S3 URIs in each active `CREATE FOREIGN TABLE` (T-100 placeholders use `<market_file>` / `<segment_file>`).

1. **pg_predeploy.sql** — database, schemas, PostGIS, `pg_analytics` / `pg_analytics_s3` server
2. **cal_load.sql** — calendar dimension tables (no external files)
3. **dim_load.sql** — dimensions from S3 via pg_analytics (`/DIMS/CSV/...`)
4. **fin_load.sql** — Form 41 inventory from S3 via pg_analytics (`/FIN/CSV/...`)
5. **otp_load.sql** — OTP via `airline_flight_performance_fdw` (adjust S3 URI per file as needed)
6. **db1b_load.sql** — DB1B ticket/coupon/market via `airfare_survey_*_fdw`
7. **t100_load.sql** — T-100 market/segment via `f41_traffic_t100_*_fdw`
8. **pg_postdeploy.sql** — vacuum, validation, drop staging tables
