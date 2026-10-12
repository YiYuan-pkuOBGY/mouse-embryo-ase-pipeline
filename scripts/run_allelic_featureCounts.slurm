#!/bin/bash
# Resource options are supplied by submit_ASE_pipeline.sh.
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: sbatch $0 SAMPLE MATERNAL_BAM PATERNAL_BAM"; exit 1; }
SAMPLE="$1"; MATERNAL_BAM="$2"; PATERNAL_BAM="$3"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="${ASE_PIPELINE_CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"
[[ -s "$CONFIG" ]] || { echo "ERROR: configuration missing: $CONFIG"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${RNASEQ_ENV:?}" "${ASE_ENV:?}" "${GTF:?}" "${COUNT_DIR:?}"
FEATURECOUNTS="${RNASEQ_ENV}/bin/featureCounts"; SAMTOOLS="${ASE_ENV}/bin/samtools"
SAMPLE_OUT="${COUNT_DIR}/${SAMPLE}"; THREADS="${SLURM_CPUS_PER_TASK:-${COUNT_CPUS:-8}}"
STRANDEDNESS="${STRANDEDNESS:-0}"
[[ -x "$FEATURECOUNTS" && -x "$SAMTOOLS" ]] || { echo "ERROR: featureCounts/samtools missing"; exit 1; }
[[ -s "$MATERNAL_BAM" && -s "$PATERNAL_BAM" && -s "$GTF" ]] || { echo "ERROR: BAM or GTF missing"; exit 1; }
"$SAMTOOLS" quickcheck -v "$MATERNAL_BAM"; "$SAMTOOLS" quickcheck -v "$PATERNAL_BAM"
mkdir -p "$SAMPLE_OUT"
RAW="${SAMPLE_OUT}/${SAMPLE}.allelic.featureCounts.txt"
SIMPLE="${SAMPLE_OUT}/${SAMPLE}.maternal_paternal_counts.tsv"
INFO="${SAMPLE_OUT}/${SAMPLE}.featureCounts_run_info.txt"
{
  echo "Sample: $SAMPLE"; echo "Maternal BAM: $MATERNAL_BAM"; echo "Paternal BAM: $PATERNAL_BAM"
  echo "GTF: $GTF"; echo "Strandedness: $STRANDEDNESS"; "$FEATURECOUNTS" -v 2>&1 || true
} > "$INFO"
"$FEATURECOUNTS" -T "$THREADS" -p --countReadPairs -B -C --primary \
  -s "$STRANDEDNESS" -t exon -g gene_id -a "$GTF" -o "$RAW" "$MATERNAL_BAM" "$PATERNAL_BAM"
[[ -s "$RAW" && -s "${RAW}.summary" ]] || { echo "ERROR: count output missing"; exit 1; }
awk 'BEGIN{OFS="\t"} /^#/ {next}
  $1=="Geneid" {print "Geneid","Maternal_count","Paternal_count","Allelic_total","Maternal_fraction","Paternal_fraction"; next}
  {m=$(NF-1);p=$NF;t=m+p;mf=(t>0?m/t:"NA");pf=(t>0?p/t:"NA");print $1,m,p,t,mf,pf}
' "$RAW" > "$SIMPLE"
awk 'BEGIN{OFS="\t"} NR>1 {m+=$2;p+=$3;if($4>0)g++;if($2>0&&$3>0)b++}
  END{print "Maternal assigned fragments",m+0;print "Paternal assigned fragments",p+0;print "Genes with allelic counts",g+0;print "Genes detected from both alleles",b+0}
' "$SIMPLE" >> "$INFO"
echo "Allelic gene counting completed successfully"
echo "FinalCounts=$SIMPLE"
echo "Summary=${RAW}.summary"
