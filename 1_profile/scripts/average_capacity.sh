#!/bin/bash
awk -F',' '
FNR > 1 {
  sum += $4
  count++
}
END {
  print "rows:", count
  print "average_capacity_TB:", sum / count / 1000000000000
}' "$@"
