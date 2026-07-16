#!/bin/bash
awk -F',' 'FNR > 1 {print $3}' "$@" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 20
