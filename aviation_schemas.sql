-- schemas
CREATE SCHEMA IF NOT EXISTS air_oai_facts;
CREATE SCHEMA IF NOT EXISTS air_oai_dims;
create schema if not exists airlines_pg;
CREATE SCHEMA IF NOT EXISTS calendar_pg;
--CREATE SCHEMA IF NOT EXISTS air_oai_parts;
CREATE SCHEMA IF NOT EXISTS geography;
CREATE SCHEMA IF NOT EXISTS zed_meta;

comment on schema air_oai_dims is 'Dimension data tables and associated foreign tables for processing OAI dimension data.';
comment on schema air_oai_facts is 'Fact data and associated foreign tables and materialized views for processing OAI fact data.';
comment on schema airlines_pg is 'Views that simplify the presentation of schemata like air_ for analysis tools, such as MicroStrategy.';
comment on schema calendar_pg is 'Gregorian calendar data as well as time transformation for ROLAP analysis.';
--comment on schema air_oai_parts is 'Holds partition tables for data tables in schema air_oai_facts.';
comment on schema geography is 'geo-political dimension and spatial data in support of aviation analysis.';
comment on schema zed_meta is 'Metadata and examples from documentation to assist with Postgres design and analysis.';
