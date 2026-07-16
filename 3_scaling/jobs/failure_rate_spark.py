#!/usr/bin/env python3
"""Phase 3 PySpark job: Backblaze drive failure analysis on Dataproc.
Submit with:
  gcloud dataproc jobs submit pyspark failure_rate_spark.py \
      --cluster <c> --region <r> \
      -- --input gs://bucket/backblaze/'*'/'*'.csv --output gs://bucket/out
"""
import argparse
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    LongType,
    IntegerType,
)


def build_schema() -> StructType:
    # The raw CSV has ~190 columns, but the first five are all we need.
    # Spark applies this schema positionally (enforceSchema) and prunes the
    # remaining columns, so we never pay to parse the SMART_* fields.
    return StructType(
        [
            StructField("date", StringType(), True),
            StructField("serial_number", StringType(), True),
            StructField("model", StringType(), True),
            StructField("capacity_bytes", LongType(), True),
            StructField("failure", IntegerType(), True),
        ]
    )


def manufacturer_col():
    """Derive a manufacturer from the model string (used for the join)."""
    model = F.col("model")
    upper = F.upper(model)
    return (
        F.when(upper.startswith("ST"), F.lit("Seagate"))
        .when(upper.startswith("WDC"), F.lit("WDC"))
        .when(upper.startswith("HGST"), F.lit("HGST"))
        .when(upper.startswith("TOSHIBA"), F.lit("Toshiba"))
        .when(upper.startswith("SAMSUNG"), F.lit("Samsung"))
        .when(upper.startswith("HITACHI"), F.lit("Hitachi"))
        .when(upper.startswith("MICRON"), F.lit("Micron"))
        .when(upper.startswith("CT"), F.lit("Crucial"))
        .when(upper.startswith("DELLBOSS"), F.lit("Dell"))
        .otherwise(F.lit("Other"))
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="gs:// glob of raw CSVs")
    parser.add_argument("--output", required=True, help="gs:// output prefix")
    parser.add_argument(
        "--min-drive-days",
        type=int,
        default=50000,
        help="Only report models with at least this many drive-days",
    )
    parser.add_argument(
        "--sql",
        action="store_true",
        help="Also run the model aggregation via Spark SQL and print it",
    )
    args = parser.parse_args()

    spark = SparkSession.builder.appName("backblaze_failure_rate").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    start = time.time()

    # Read with explicit schema 
    raw = (
        spark.read.option("header", True)
        .option("mode", "PERMISSIVE")
        .schema(build_schema())
        .csv(args.input)
    )

    # Transform: clean and get manufacturer, then save
    drives = (
        raw.filter(F.col("model").isNotNull() & (F.col("model") != ""))
        .withColumn("manufacturer", manufacturer_col())
        .withColumn(
            "capacity_bytes",
            F.when(F.col("capacity_bytes") > 0, F.col("capacity_bytes")),
        )
        .select("date", "model", "manufacturer", "capacity_bytes", "failure")
        .cache()
    )

    total_rows = drives.count()  # action -> materializes the cache
    print(f"TOTAL_DRIVE_DAYS={total_rows}")

    # groupBy aggregation: per-model failure stats
    by_model = (
        drives.groupBy("manufacturer", "model")
        .agg(
            F.count(F.lit(1)).alias("drive_days"),
            F.sum("failure").alias("failures"),
            F.avg("capacity_bytes").alias("avg_capacity_bytes"),
        )
        .withColumn(
            "afr_percent",
            F.round(F.col("failures") / F.col("drive_days") * F.lit(365) * F.lit(100), 4),
        )
        .filter(F.col("drive_days") >= args.min_drive_days)
    )

    # rank models by failure rate
    afr_window = Window.orderBy(F.col("afr_percent").desc())
    ranked_models = by_model.withColumn("afr_rank", F.rank().over(afr_window))

    # aggregation at the manufacturer level 
    by_mfr = (
        drives.groupBy("manufacturer")
        .agg(
            F.count(F.lit(1)).alias("mfr_drive_days"),
            F.sum("failure").alias("mfr_failures"),
        )
        .withColumn(
            "mfr_afr_percent",
            F.round(F.col("mfr_failures") / F.col("mfr_drive_days") * F.lit(365) * F.lit(100), 4),
        )
    )

    # attach each models manufacturer baseline and share 
    joined = (
        ranked_models.join(by_mfr, on="manufacturer", how="inner")
        .withColumn(
            "share_of_mfr_fleet",
            F.round(F.col("drive_days") / F.col("mfr_drive_days"), 4),
        )
        .withColumn(
            "afr_vs_mfr_avg",
            F.round(F.col("afr_percent") - F.col("mfr_afr_percent"), 4),
        )
        .orderBy("afr_rank")
    )

    print("=== Top models by annualized failure rate ===")
    joined.show(20, truncate=False)

    (
        joined.coalesce(1)
        .write.mode("overwrite")
        .option("header", True)
        .csv(f"{args.output}/failure_rate_by_model")
    )

    # same model aggregation via Spark SQL for comparison
    if args.sql:
        drives.createOrReplaceTempView("drives")
        sql_df = spark.sql(
            f"""
            SELECT model,
                   COUNT(*)                                   AS drive_days,
                   SUM(failure)                               AS failures,
                   ROUND(SUM(failure)/COUNT(*)*365*100, 4)    AS afr_percent
            FROM drives
            GROUP BY model
            HAVING COUNT(*) >= {args.min_drive_days}
            ORDER BY afr_percent DESC
            LIMIT 20
            """
        )
        print("=== Spark SQL: top models by AFR ===")
        sql_df.show(20, truncate=False)

    elapsed = time.time() - start
    print(f"JOB_ELAPSED_SECONDS={elapsed:.2f}")

    spark.stop()


if __name__ == "__main__":
    main()
