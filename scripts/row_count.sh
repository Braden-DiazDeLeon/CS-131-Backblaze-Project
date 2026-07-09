#!/bin/bash
awk 'FNR > 1 {count++} END {print count}' "$@"
