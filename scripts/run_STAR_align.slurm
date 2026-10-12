#!/bin/bash
# Resource options are supplied by submit_ASE_pipeline.sh.
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: sbatch $0 SAMPLE R1 R2"; exit 1; }
SAMPLE="$1"; R1="$2"; R2="$3"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="${ASE_PIPELINE_CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"
[[ -s "$CONFIG" ]] || { echo "ERROR: configuration missing: $CONFIG"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${ASE_ENV:?}" "${STAR_INDEX:?}" "${ALIGN_DIR:?}"
STAR="${ASE_ENV}/bin/STAR"; SAMTOOLS="${ASE_ENV}/bin/samtools"
PREFIX="${ALIGN_DIR}/${SAMPLE}."; BAM="${PREFIX}Aligned.out.bam"
[[ -x "$STAR" && -x "$SAMTOOLS" ]] || { echo "ERROR: STAR/samtools missing"; exit 1; }
[[ -s "$R1" && -s "$R2" ]] || { echo "ERROR: FASTQ missing or empty"; exit 1; }
[[ -s "${STAR_INDEX}/Genome" ]] || { echo "ERROR: STAR index missing"; exit 1; }
mkdir -p "$ALIGN_DIR"
"$STAR" --runThreadN "${SLURM_CPUS_PER_TASK:-${STAR_CPUS:-16}}" \
  --genomeDir "$STAR_INDEX" --readFilesIn "$R1" "$R2" --readFilesCommand zcat \
  --alignEndsType EndToEnd --outFilterMultimapNmax 1 \
  --outSAMattributes NH HI AS nM NM MD --outSAMtype BAM Unsorted \
  --outSAMunmapped Within --outFileNamePrefix "$PREFIX"
"$SAMTOOLS" quickcheck -v "$BAM"
set +o pipefail
"$SAMTOOLS" view -F 4 "$BAM" | head -n 1000 | grep -q $'\tMD:Z:'
MD_STATUS=$?
set -o pipefail
[[ $MD_STATUS -eq 0 ]] || { echo "ERROR: MD tag missing"; exit 1; }
echo "STAR alignment completed successfully"
echo "BAM=$BAM"
echo "FINAL_LOG=${PREFIX}Log.final.out"
