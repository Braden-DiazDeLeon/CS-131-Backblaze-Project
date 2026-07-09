#!/bin/bash
awk -F',' '
FNR > 1 {
  if ($1 >= "2025-07-01" && $1 <= "2025-09-30") {
    q = "2025_Q3"
  } else if ($1 >= "2026-01-01" && $1 <= "2026-03-31") {
    q = "2026_Q1"
  } else {
    q = "other"
  }

  drive_days[q]++
  failures[q] += $5
}
END {
  print "quarter,drive_days,failures,annualized_failure_rate_percent"
  for (q in drive_days) {
    afr = failures[q] / drive_days[q] * 365 * 100
    print q "," drive_days[q] "," failures[q] "," afr
  }
}' "$@"
