#!/bin/bash
set -euo pipefail

export LC_ALL=C

# Resolve paths relative to this script so it can be run from anywhere.
# Layout: 1_profile/scripts/run_phase1_profiling.sh -> 1_profile/ is the base.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

# Location of the raw Backblaze CSVs (kept out of the repo / home dir).
# Override with: DATA_DIR=/path/to/backblaze scripts/run_phase1_profiling.sh
DATA_DIR="${DATA_DIR:-$HOME/backblaze}"

mkdir -p outputs

FILES=("$DATA_DIR"/q3_2025/data_Q3_2025/*.csv "$DATA_DIR"/q1_2026/data_Q1_2026/*.csv)

echo "1. Disk size"
time du -sh "$DATA_DIR/q3_2025" "$DATA_DIR/q1_2026" > outputs/disk_size.txt

echo "2. Detailed disk size"
time du -h --max-depth=2 "$DATA_DIR/q3_2025" "$DATA_DIR/q1_2026" | sort -h > outputs/disk_size_detailed.txt

echo "3. CSV file count"
time find "$DATA_DIR/q3_2025" "$DATA_DIR/q1_2026" -name "*.csv" | wc -l > outputs/csv_file_count.txt

echo "4. Row count"
time scripts/row_count.sh "${FILES[@]}" > outputs/row_count.txt

echo "5. Header row"
time head -n 1 "$DATA_DIR/q3_2025/data_Q3_2025/2025-07-01.csv" > outputs/header.txt

echo "6. Schema with column numbers"
time bash -c 'head -n 1 "$1" | tr "," "\n" | nl -ba' bash "$DATA_DIR/q3_2025/data_Q3_2025/2025-07-01.csv" > outputs/schema_columns.txt

echo "7. First sample rows"
time bash -c 'head -n 6 "$1" | cut -d"," -f1-5 | column -t -s","' bash "$DATA_DIR/q3_2025/data_Q3_2025/2025-07-01.csv" > outputs/head_sample.txt

echo "8. Last sample rows"
time bash -c 'tail -n 5 "$1" | cut -d"," -f1-5 | column -t -s","' bash "$DATA_DIR/q1_2026/data_Q1_2026/2026-03-31.csv" > outputs/tail_sample.txt

echo "9. Top drive models"
time scripts/top_models.sh "${FILES[@]}" > outputs/top_models.txt

echo "10. Unique drive model count"
time scripts/unique_models.sh "${FILES[@]}" > outputs/unique_models.txt

echo "11. Top capacities"
time scripts/top_capacities.sh "${FILES[@]}" > outputs/top_capacities.txt

echo "12. Failure count using grep -c"
time bash -c 'grep -hEc "^[^,]*,[^,]*,[^,]*,[^,]*,1," "$@" | awk "{s+=\$1} END {print s}"' bash "${FILES[@]}" > outputs/grep_failure_count.txt

echo "13. Failure count using awk"
time scripts/failure_count.sh "${FILES[@]}" > outputs/failure_count.txt

echo "14. Average capacity"
time scripts/average_capacity.sh "${FILES[@]}" > outputs/average_capacity.txt

echo "15. Failure rate by model"
time scripts/failure_rate_by_model.sh "${FILES[@]}" > outputs/failure_rate_by_model.csv

echo "16. Failure rate by quarter"
time scripts/failure_rate_by_quarter.sh "${FILES[@]}" > outputs/failure_rate_by_quarter.csv

echo "Done. Outputs saved in outputs/."
