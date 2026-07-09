#!/bin/bash
awk -F',' 'FNR > 1 {print $4}' "$@" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 20
