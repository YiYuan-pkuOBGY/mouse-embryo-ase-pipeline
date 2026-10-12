#!/bin/bash
# Resource options are supplied by submit_ASE_pipeline.sh.
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: sbatch $0 SAMPLE INPUT_BAM MOTHER"; exit 1; }
SAMPLE="$1"; INPUT_BAM="$2"; MOTHER="$3"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="${ASE_PIPELINE_CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"
[[ -s "$CONFIG" ]] || { echo "ERROR: configuration missing: $CONFIG"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${ASE_ENV:?}" "${SNP_FILE:?}" "${ALLELE_DIR:?}"
SAMTOOLS="${ASE_ENV}/bin/samtools"; SNPSPLIT="${ASE_ENV}/bin/SNPsplit"
SAMPLE_OUT="${ALLELE_DIR}/${SAMPLE}"; THREADS="${SLURM_CPUS_PER_TASK:-${SNPSPLIT_CPUS:-8}}"
case "$MOTHER" in
  BDF1) G1_ORIGIN="maternal"; G2_ORIGIN="paternal"; FATHER="CAST" ;;
  CAST) G1_ORIGIN="paternal"; G2_ORIGIN="maternal"; FATHER="BDF1" ;;
  *) echo "ERROR: MOTHER must be BDF1 or CAST"; exit 1 ;;
esac
[[ -x "$SAMTOOLS" && -x "$SNPSPLIT" ]] || { echo "ERROR: samtools/SNPsplit missing"; exit 1; }
[[ -s "$INPUT_BAM" && -s "$SNP_FILE" ]] || { echo "ERROR: BAM or SNP file missing"; exit 1; }
mkdir -p "$SAMPLE_OUT"; "$SAMTOOLS" quickcheck -v "$INPUT_BAM"
set +o pipefail
"$SAMTOOLS" view -F 4 "$INPUT_BAM" | head -n 1000 | grep -q $'\tMD:Z:'
MD_STATUS=$?
set -o pipefail
[[ $MD_STATUS -eq 0 ]] || { echo "ERROR: MD tag missing"; exit 1; }
SORTED="${SAMPLE_OUT}/${SAMPLE}.name_sorted.bam"
"$SAMTOOLS" sort -n -@ "$THREADS" -m 4G -T "${SAMPLE_OUT}/${SAMPLE}.sort_tmp" -o "$SORTED" "$INPUT_BAM"
"$SAMTOOLS" quickcheck -v "$SORTED"
"$SNPSPLIT" --paired --no_sort --conflicting --output_dir "$SAMPLE_OUT" --snp_file "$SNP_FILE" "$SORTED"
G1="${SORTED%.bam}.genome1.bam"; G2="${SORTED%.bam}.genome2.bam"
UA="${SORTED%.bam}.unassigned.bam"; CF="${SORTED%.bam}.conflicting.bam"
for F in "$G1" "$G2" "$UA"; do [[ -s "$F" ]]; "$SAMTOOLS" quickcheck -v "$F"; done
[[ ! -s "$CF" ]] || "$SAMTOOLS" quickcheck -v "$CF"
for L in "${SAMPLE_OUT}/${SAMPLE}.maternal.BDF1.bam" "${SAMPLE_OUT}/${SAMPLE}.maternal.CAST.bam" \
         "${SAMPLE_OUT}/${SAMPLE}.paternal.BDF1.bam" "${SAMPLE_OUT}/${SAMPLE}.paternal.CAST.bam"; do
  [[ ! -L "$L" ]] || unlink "$L"
done
if [[ "$MOTHER" == "BDF1" ]]; then
  ln -s "$(basename "$G1")" "${SAMPLE_OUT}/${SAMPLE}.maternal.BDF1.bam"
  ln -s "$(basename "$G2")" "${SAMPLE_OUT}/${SAMPLE}.paternal.CAST.bam"
  MAT_BAM="${SAMPLE_OUT}/${SAMPLE}.maternal.BDF1.bam"; PAT_BAM="${SAMPLE_OUT}/${SAMPLE}.paternal.CAST.bam"
else
  ln -s "$(basename "$G2")" "${SAMPLE_OUT}/${SAMPLE}.maternal.CAST.bam"
  ln -s "$(basename "$G1")" "${SAMPLE_OUT}/${SAMPLE}.paternal.BDF1.bam"
  MAT_BAM="${SAMPLE_OUT}/${SAMPLE}.maternal.CAST.bam"; PAT_BAM="${SAMPLE_OUT}/${SAMPLE}.paternal.BDF1.bam"
fi
cat > "${SAMPLE_OUT}/${SAMPLE}.allele_definition.txt" <<EOF
Sample: ${SAMPLE}
Maternal strain: ${MOTHER}
Paternal strain: ${FATHER}
Genome1 strain: BDF1
Genome2 strain: CAST
Genome1 parental origin: ${G1_ORIGIN}
Genome2 parental origin: ${G2_ORIGIN}
Maternal BAM: ${MAT_BAM}
Paternal BAM: ${PAT_BAM}
SNP file: ${SNP_FILE}
Input BAM: ${INPUT_BAM}
EOF
echo "SNPsplit completed successfully"
echo "MaternalBAM=$MAT_BAM"
echo "PaternalBAM=$PAT_BAM"
