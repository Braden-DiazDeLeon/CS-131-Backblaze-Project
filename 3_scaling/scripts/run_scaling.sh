#!/bin/bash
# scaling experiment: run the same PySpark job on N workers.

set -euo pipefail

WORKERS="${1:?Usage: run_scaling.sh <num_workers: 1|2|4>}"

PROJECT="${PROJECT:-<gcp-project-id>}"
REGION="${REGION:-us-west1}"
BUCKET="${BUCKET:-gs://<your-bucket>}"
INPUT="${INPUT:-$BUCKET/backblaze/*/*/*.csv}"
OUTPUT="${OUTPUT:-$BUCKET/backblaze_out/workers_${WORKERS}}"
CLUSTER="${CLUSTER:-backblaze-scale-${WORKERS}}"
MACHINE="${MACHINE:-n2-standard-4}"
IMAGE_VERSION="${IMAGE_VERSION:-2.2-debian12}"
# Small boot disks to stay under the DISKS_TOTAL_GB quota.
# Dataproc defaults to 1000GB/node; 4 workers + master would need 5000GB.
# With 100GB each, a 4-worker cluster only needs 5 * 100 = 500GB.
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-100}"
BOOT_DISK_TYPE="${BOOT_DISK_TYPE:-pd-standard}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
JOB="$BASE_DIR/jobs/failure_rate_spark.py"
RESULTS_DIR="$BASE_DIR/results"
mkdir -p "$RESULTS_DIR"
LOG="$RESULTS_DIR/scaling_workers_${WORKERS}.log"

echo "=== Creating cluster $CLUSTER ($WORKERS worker[s]) ===" | tee "$LOG"
if [[ "$WORKERS" -le 1 ]]; then
  gcloud dataproc clusters create "$CLUSTER" \
    --project "$PROJECT" --region "$REGION" \
    --single-node --master-machine-type "$MACHINE" \
    --master-boot-disk-type "$BOOT_DISK_TYPE" \
    --master-boot-disk-size "$BOOT_DISK_SIZE" \
    --image-version "$IMAGE_VERSION" 2>&1 | tee -a "$LOG"
else
  gcloud dataproc clusters create "$CLUSTER" \
    --project "$PROJECT" --region "$REGION" \
    --master-machine-type "$MACHINE" \
    --master-boot-disk-type "$BOOT_DISK_TYPE" \
    --master-boot-disk-size "$BOOT_DISK_SIZE" \
    --num-workers "$WORKERS" --worker-machine-type "$MACHINE" \
    --worker-boot-disk-type "$BOOT_DISK_TYPE" \
    --worker-boot-disk-size "$BOOT_DISK_SIZE" \
    --image-version "$IMAGE_VERSION" 2>&1 | tee -a "$LOG"
fi

echo "=== Submitting job (workers=$WORKERS) ===" | tee -a "$LOG"
START=$(date +%s)
gcloud dataproc jobs submit pyspark "$JOB" \
  --project "$PROJECT" --region "$REGION" --cluster "$CLUSTER" \
  -- --input "$INPUT" --output "$OUTPUT" 2>&1 | tee -a "$LOG"
END=$(date +%s)
RUNTIME=$((END - START))

echo "=== RESULT workers=$WORKERS wall_clock=${RUNTIME}s ===" | tee -a "$LOG"
echo "(also grep JOB_ELAPSED_SECONDS in the log for the pure job time)" | tee -a "$LOG"

echo "=== Deleting cluster $CLUSTER ===" | tee -a "$LOG"
gcloud dataproc clusters delete "$CLUSTER" \
  --project "$PROJECT" --region "$REGION" --quiet 2>&1 | tee -a "$LOG"

echo "Done. Log saved to $LOG"
