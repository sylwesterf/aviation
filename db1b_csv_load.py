import psycopg
import os
import csv

conn = psycopg.connect(
    host="ts-pgsql14",
    dbname="sfron1726676831",
    user="",
    password=""
)


BATCH_SIZE = 100000
#adjust for the table
TARGET_COLUMN_COUNT = 42


def unzip_files(zip_folder_path, destination_folder):
    """Unzip all files in the zip_folder_path to the destination_folder."""
    for item in os.listdir(zip_folder_path):
        #print(os.listdir(zip_folder_path))
        #print(item)
        if item.endswith('.zip'):
            file_path = os.path.join(zip_folder_path, item)
            #print(file_path)
            with zipfile.ZipFile(file_path, 'r') as zip_ref:
                #print(zip_ref.printdir())
                zip_ref.extractall(path=destination_folder)
            print(f"Unzipped: {item}")


def load_data_with_copy(conn, table_name, csv_folder_path):
    """Loads data from a CSV file into an existing PostgreSQL table using the COPY command."""
#open all files with .csv on the end one by one
    for file_name in os.listdir(csv_folder_path):
        if file_name.endswith('.csv'):
            file_path = os.path.join(csv_folder_path, file_name)
            table_name = table_name
            print(file_path)
            row_count = 0
            # Use DataFrame to_sql method to populate database table
            cursor = conn.cursor()
            total_rows = 0
            batch = []
            try:
                with open(file_path, 'r') as f:
                    next(f)  # Skip header
                    #load csv file
                    reader = csv.reader(f, delimiter=',')
                    #check if tghe csv file has the same number of columns, and limit the file to the desire number 
                    for row in reader:
                        if len(row) > TARGET_COLUMN_COUNT:
                            row_to_load = row[:TARGET_COLUMN_COUNT]
                            batch.append(','.join(row_to_load) + '\n')
                        elif len(row) == TARGET_COLUMN_COUNT:
                            batch.append(','.join(row) + '\n')
                        else:
                            print(f"Skipping row with fewer columns than target: {row}")
                            continue
                        #check if in the batch is max number of rows, if yes, then its Copy it into database and commit
                        if len(batch) >= BATCH_SIZE:
                            data_to_copy = "".join(batch).encode('utf-8')
                            try:
                                with cursor.copy(
                                        f"COPY {table_name} FROM STDIN WITH (FORMAT CSV, DELIMITER ',')") as copy:
                                    copy.write(data_to_copy)
                                conn.commit()
                                total_rows += len(batch)
                                print(f"Loaded {total_rows} rows.")
                            except Exception as e:
                                conn.rollback()
                                print(f"Error during COPY batch: {e}")
                                return
                            batch = []

                    # Process any remaining rows
                    if batch:
                        data_to_copy = "".join(batch).encode('utf-8')
                        try:
                            with cursor.copy(f"COPY {table_name} FROM STDIN WITH (FORMAT CSV, DELIMITER ',')") as copy:
                                copy.write(data_to_copy)
                            conn.commit()
                            total_rows += len(batch)
                            print(f"Loaded final {len(batch)} rows. Total {total_rows} rows.")
                        except Exception as e:
                            conn.rollback()
                            print(f"Error during final COPY: {e}")

            except FileNotFoundError:
                print(f"Error: CSV file not found.")
            except Exception as e:
                print(f"An unexpected error occurred: {e}")
            finally:
                cursor.close()


load_data_with_copy(csv_folder_path=r'C:\Users\mmarcinkowski\Downloads\DB Benchmark\DB1B\csv\_market', conn=conn, table_name= "air_oai_facts.airfare_survey_market_load")

#load Coupons from _load to final table
import psycopg2

# Database connection details (replace with your PostgreSQL credentials)
DB_CONFIG = {
    'host': 'ts-pgsql14',
    'database': 'sfron1726676831',
    'user': 'sfron1726676831',
    'password': '',
}

connection = psycopg2.connect(
    host="ts-pgsql14",
    database="sfron1726676831",
    user="sfron1726676831",
    password=""
)
INSERT_SQL = """
INSERT INTO air_oai_facts.airfare_survey_coupon
	(itinerary_oai_id, flight_pass_seq, year_quarter_start_date, market_oai_id
	, ticketing_airline_entity_id, ticketing_airline_entity_key
	, operating_airline_entity_id, operating_airline_entity_key
	, reporting_airline_entity_id, reporting_airline_entity_key
	, depart_airport_history_id, depart_airport_history_key
	, arrive_airport_history_id, arrive_airport_history_key
	, trip_break_code, gateway_ind, distance_group_oai_id, airfare_class_code
	, itinerary_geographic_type_oai_id, coupon_geographic_type_oai_id
	, flight_pass_type, flight_pass_qty, passengers_qty, distance_smi
	, created_by, created_tmst)
SELECT ac.itinerary_oai_id
, ac.flight_pass_seq
, (ac.year_nbr::text || case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01'
 when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date as year_quarter_start_date
	 , ac.market_oai_id
	 , aet.airline_entity_id as ticketing_airline_entity_id
	 , aet.airline_entity_key as ticketing_airline_entity_key
	 , aeo.airline_entity_id as operating_airline_entity_id
	 , aeo.airline_entity_key as operating_airline_entity_key
	 , aer.airline_entity_id as reporting_airline_entity_id
	 , aer.airline_entity_key as reporting_airline_entity_key
	 , ahd.airport_history_id as depart_airport_history_id
	 , ahd.airport_history_key as depart_airport_history_key
	 , aha.airport_history_id as arrive_airport_history_id
	 , ahd.airport_history_key as arrive_airport_history_key
	 , case when ac.trip_break_code = 'X' then 1 else 0 end::smallint as trip_break_code
	 , ac.gateway_ind
	 , ac.distance_group_id
	 , ac.airfare_class_code
	 , ac.itinerary_geo_type_id as itinerary_geographic_type_id
	 , ac.coupon_geo_type_id as coupon_geographic_type_id
	 , ac.flight_pass_type
	 , ac.flight_pass_qty
	 , ac.passengers_qty
	 , ac.distance_smi
	 , current_user
	 , current_timestamp
FROM air_oai_facts.airfare_survey_coupon_load ac
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aet
on ac.ticketing_airline_oai_code = aet.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aeo
on ac.operating_airline_oai_code = aeo.airline_oai_code
left join (select * from air_oai_dims.airline_entities where operating_region_code = 'Domestic') aer
on ac.reporting_airline_oai_code = aer.airline_oai_code
left join air_oai_dims.airport_history ahd
on ac.depart_airport_oai_seq_id = ahd.airport_oai_seq_id
left join air_oai_dims.airport_history aha
on ac.arrive_airport_oai_seq_id = aha.airport_oai_seq_id
WHERE ac.ticketing_airline_oai_code = %s
and (ac.year_nbr::text ||
case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01'
when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
between aet.source_from_date and coalesce(aet.source_thru_date, current_date)
and (ac.year_nbr::text ||
case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01'
when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
between aeo.source_from_date and coalesce(aeo.source_thru_date, current_date)
and(ac.year_nbr::text ||
case when ac.quarter_nbr = 1 then '-01-01' when ac.quarter_nbr = 2 then '-04-01'
when ac.quarter_nbr = 3 then '-07-01' when ac.quarter_nbr = 4 then '-10-01' else null end::text)::date
between aer.source_from_date and coalesce(aer.source_thru_date, current_date)
;"""

def get_distinct_airline_entity_ids():
    """Fetches the distinct ticketing_airline_entity_id values from the load table."""
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute("SELECT DISTINCT ticketing_airline_oai_code FROM air_oai_facts.airfare_survey_coupon_load WHERE ticketing_airline_oai_code IS NOT NULL")
        airline_ids = [row[0] for row in cursor.fetchall()]
        return airline_ids
    except psycopg2.Error as e:
        print(f"Error fetching ticketing_airline_oai_code's: {e}")
        return []
    finally:
        if conn:
            conn.close()

def load_data_by_airline(airline_entity_id):
    """Loads data for a specific ticketing_airline_entity_id."""
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute(INSERT_SQL, (airline_entity_id,))
        row_count = cursor.rowcount
        conn.commit()
        print(f"Loaded {row_count} rows for airline_entity_id: {airline_entity_id}")
    except psycopg2.Error as e:
        conn.rollback()
        print(f"Error loading data for airline ID {airline_entity_id}: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    airline_entity_ids = get_distinct_airline_entity_ids()
    print(f"Found {len(airline_entity_ids)} distinct ticketing airline entity IDs.")
    for airline_id in airline_entity_ids:
        load_data_by_airline(airline_id)
    print("Data loading process complete.")
