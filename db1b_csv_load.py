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
