#!/bin/bash
# Phase 3, step 1: put the raw Backblaze CSVs in a GCS bucket so Spark can read
# them directly via gs://... (we never copy multi-GB files into $HOME on the
# cluster). Run this ONCE from the VM where the data lives (~/backblaze).
#
# Usage:
#   PROJECT=my-proj REGION=us-west1 BUCKET=gs://my-bucket ./upload_to_gcs.sh
set -euo pipefail

PROJECT="${PROJECT:-<gcp-project-id>}"
REGION="${REGION:-us-west1}"
BUCKET="${BUCKET:-gs://<your-bucket>}"

# Where the extracted CSVs live on the VM (relative to ~/backblaze).
DATA_DIR="${DATA_DIR:-$HOME/backblaze}"

echo "=== Creating bucket $BUCKET (ok if it already exists) ==="
gcloud storage buckets create "$BUCKET" \
  --project "$PROJECT" --location "$REGION" || true

echo "=== Uploading Q3 2025 CSVs ==="
gcloud storage cp --recursive \
  "$DATA_DIR/q3_2025/data_Q3_2025" "$BUCKET/backblaze/q3_2025/"

echo "=== Uploading Q1 2026 CSVs ==="
gcloud storage cp --recursive \
  "$DATA_DIR/q1_2026/data_Q1_2026" "$BUCKET/backblaze/q1_2026/"

echo "=== Done. Verify: ==="
echo "gcloud storage ls $BUCKET/backblaze/q3_2025/data_Q3_2025/ | head"
echo "Input glob for the Spark job:"
echo "  $BUCKET/backblaze/*/*/*.csv"
