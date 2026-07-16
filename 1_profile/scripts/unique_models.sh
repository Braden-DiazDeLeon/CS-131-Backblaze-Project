#!/bin/bash
awk -F',' 'FNR > 1 {print $3}' "$@" \
  | sort \
  | uniq \
  | wc -l
