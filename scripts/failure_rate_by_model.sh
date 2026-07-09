#!/bin/bash
awk -F',' '
FNR > 1 {
  model = $3
  drive_days[model]++
  failures[model] += $5
}
END {
  print "model,drive_days,failures,annualized_failure_rate_percent"
  for (m in drive_days) {
    if (drive_days[m] >= 100000) {
      afr = failures[m] / drive_days[m] * 365 * 100
      print m "," drive_days[m] "," failures[m] "," afr
    }
  }
}' "$@" | sort -t',' -k4,4nr
