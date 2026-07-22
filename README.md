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

DuckDB execution order:

1. **predeploy.sql** — database, schemas, extensions
2. **cal_load.sql** — calendar dimension tables (no external files)
3. **dim_load.sql** — dimensions from S3 via read_csv (`/DIMS/CSV/...`)
4. **fin_load.sql** — Form 41 inventory from S3 via read_csv (`/FIN/CSV/...`)
5. **otp_load.sql** — OTP from S3 via read_csv (`/OTP/CSV/...`)
6. **db1b_load.sql** — DB1B ticket/coupon/market from S3 via read_csv (`/DB1B/CSV/...`)
7. **t100_load.sql** — T-100 market/segment from S3 via read_csv (`/T100/CSV/...`)
8. **postdeploy.sql** — vacuum, validation, drop staging tables
