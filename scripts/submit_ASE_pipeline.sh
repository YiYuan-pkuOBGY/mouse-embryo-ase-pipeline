#!/bin/bash
set -euo pipefail
[[ $# -eq 4 ]] || { echo "Usage: bash $0 SAMPLE R1 R2 MOTHER"; echo "MOTHER must be BDF1 or CAST"; exit 1; }
SAMPLE="$1"; R1="$2"; R2="$3"; MOTHER="$4"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="${ASE_PIPELINE_CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"
[[ -s "$CONFIG" ]] || { echo "ERROR: configuration missing: $CONFIG"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${PROJECT_ROOT:?}" "${SLURM_PARTITION:?}" "${LOG_DIR:?}" "${ALIGN_DIR:?}" "${ALLELE_DIR:?}" "${COUNT_DIR:?}"
STAR_SCRIPT="${SCRIPT_DIR}/run_STAR_align.slurm"
SNPSPLIT_SCRIPT="${SCRIPT_DIR}/run_SNPsplit.slurm"
COUNT_SCRIPT="${SCRIPT_DIR}/run_allelic_featureCounts.slurm"
STAR_BAM="${ALIGN_DIR}/${SAMPLE}.Aligned.out.bam"; SPLIT_DIR="${ALLELE_DIR}/${SAMPLE}"
[[ -s "$R1" && -s "$R2" ]] || { echo "ERROR: FASTQ missing or empty"; exit 1; }
for S in "$STAR_SCRIPT" "$SNPSPLIT_SCRIPT" "$COUNT_SCRIPT"; do [[ -s "$S" ]] || { echo "ERROR: script missing: $S"; exit 1; }; done
mkdir -p "$LOG_DIR" "$ALIGN_DIR" "$ALLELE_DIR" "$COUNT_DIR"
case "$MOTHER" in
  BDF1) MATERNAL_BAM="${SPLIT_DIR}/${SAMPLE}.maternal.BDF1.bam"; PATERNAL_BAM="${SPLIT_DIR}/${SAMPLE}.paternal.CAST.bam" ;;
  CAST) MATERNAL_BAM="${SPLIT_DIR}/${SAMPLE}.maternal.CAST.bam"; PATERNAL_BAM="${SPLIT_DIR}/${SAMPLE}.paternal.BDF1.bam" ;;
  *) echo "ERROR: MOTHER must be BDF1 or CAST"; exit 1 ;;
esac
COMMON=(--parsable --partition="$SLURM_PARTITION" --export="ALL,ASE_PIPELINE_CONFIG=$CONFIG")
STAR_JOB=$(sbatch "${COMMON[@]}" --job-name=STAR_ASE \
  --cpus-per-task="${STAR_CPUS:-16}" --mem="${STAR_MEM:-50G}" --time="${STAR_TIME:-12:00:00}" \
  --output="${LOG_DIR}/%x_%j.out" --error="${LOG_DIR}/%x_%j.err" "$STAR_SCRIPT" "$SAMPLE" "$R1" "$R2")
SPLIT_JOB=$(sbatch "${COMMON[@]}" --dependency="afterok:${STAR_JOB}" --job-name=SNPsplit \
  --cpus-per-task="${SNPSPLIT_CPUS:-8}" --mem="${SNPSPLIT_MEM:-64G}" --time="${SNPSPLIT_TIME:-12:00:00}" \
  --output="${LOG_DIR}/%x_%j.out" --error="${LOG_DIR}/%x_%j.err" "$SNPSPLIT_SCRIPT" "$SAMPLE" "$STAR_BAM" "$MOTHER")
COUNT_JOB=$(sbatch "${COMMON[@]}" --dependency="afterok:${SPLIT_JOB}" --job-name=ASE_count \
  --cpus-per-task="${COUNT_CPUS:-8}" --mem="${COUNT_MEM:-24G}" --time="${COUNT_TIME:-06:00:00}" \
  --output="${LOG_DIR}/%x_%j.out" --error="${LOG_DIR}/%x_%j.err" "$COUNT_SCRIPT" "$SAMPLE" "$MATERNAL_BAM" "$PATERNAL_BAM")
RECORD="${LOG_DIR}/${SAMPLE}.pipeline_jobs.txt"
{
  echo "Sample: $SAMPLE"; echo "R1: $R1"; echo "R2: $R2"; echo "Maternal strain: $MOTHER"
  echo "STAR job: $STAR_JOB"; echo "SNPsplit job: $SPLIT_JOB"; echo "featureCounts job: $COUNT_JOB"
  echo "Final counts: ${COUNT_DIR}/${SAMPLE}/${SAMPLE}.maternal_paternal_counts.tsv"; echo "Submitted: $(date)"
} > "$RECORD"
echo "STAR_JOB=$STAR_JOB"
echo "SNPSPLIT_JOB=$SPLIT_JOB"
echo "COUNT_JOB=$COUNT_JOB"
echo "JOB_RECORD=$RECORD"
echo "FINAL_COUNTS=${COUNT_DIR}/${SAMPLE}/${SAMPLE}.maternal_paternal_counts.tsv"
