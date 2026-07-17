import os
import time

os.system("pip install pyspark --quiet")
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("breakSpark").getOrCreate()

print("Loading data")

try:
    start_time = time.time()

    df = spark.read.csv(
        "gs://break-pyspark/data_Q1_2026.zip", header=True, inferSchema=True
    )

    total_rows = df.count()
    end_time = time.time()

    print("Success - Full dataset loaded without errors!")
    print(f"Wall-Clock Time: {end_time - start_time:.2f} seconds")

except Exception as e:
    print(f"Ran out of memory while loading data! {e}")

finally:
    spark.stop()

