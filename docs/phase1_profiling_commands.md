# Phase 1 Profiling Commands

Dataset: Backblaze Drive Stats, Q3 2025 + Q1 2026

Run location:

```bash
cd ~/backblaze
```

Main command used to run all profiling:

For some context I wrote a bunch of shell scripts then used a basically master script to run all the scripts at the same time this helps for rerunability.
```bash
time scripts/run_phase1_profiling.sh 2>&1 | tee outputs/run_phase1_profiling_log.txt
```

Exact command sequence inside the profiling script:

```bash
#!/bin/bash
set -euo pipefail

export LC_ALL=C

mkdir -p outputs timings docs

FILES=(q3_2025/data_Q3_2025/*.csv q1_2026/data_Q1_2026/*.csv)

echo "1. Disk size"
time du -sh q3_2025 q1_2026 > outputs/disk_size.txt

echo "2. Detailed disk size"
time du -h --max-depth=2 q3_2025 q1_2026 | sort -h > outputs/disk_size_detailed.txt

echo "3. CSV file count"
time find q3_2025 q1_2026 -name "*.csv" | wc -l > outputs/csv_file_count.txt

echo "4. Row count"
time scripts/row_count.sh "${FILES[@]}" > outputs/row_count.txt

echo "5. Header row"
time head -n 1 q3_2025/data_Q3_2025/2025-07-01.csv > outputs/header.txt

echo "6. Schema with column numbers"
time bash -c 'head -n 1 q3_2025/data_Q3_2025/2025-07-01.csv | tr "," "\n" | nl -ba' > outputs/schema_columns.txt

echo "7. First sample rows"
time bash -c 'head -n 6 q3_2025/data_Q3_2025/2025-07-01.csv | cut -d"," -f1-5 | column -t -s","' > outputs/head_sample.txt

echo "8. Last sample rows"
time bash -c 'tail -n 5 q1_2026/data_Q1_2026/2026-03-31.csv | cut -d"," -f1-5 | column -t -s","' > outputs/tail_sample.txt

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
```
