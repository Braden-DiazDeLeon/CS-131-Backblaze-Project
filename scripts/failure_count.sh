#!/bin/bash
awk -F',' '
FNR > 1 && $5 == 1 {
  failures++
}
END {
  print failures
}' "$@"
