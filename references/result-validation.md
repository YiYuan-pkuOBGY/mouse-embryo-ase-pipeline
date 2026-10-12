# Result validation

## STAR

Require:

- Slurm `COMPLETED`, exit `0:0`.
- `<SAMPLE>.Log.out` says `finished successfully`.
- `samtools quickcheck` passes on `<SAMPLE>.Aligned.out.bam`.
- Mapped alignments contain `MD:Z:` tags.
- Review `<SAMPLE>.Log.final.out`: input reads, unique mapping, too-many-loci, mismatch rate, and unmapped categories.

`--outFilterMultimapNmax 1` intentionally puts all multi-locus reads in `mapped to too many loci`; zero ordinary multi-mappers is expected.

## SNPsplit

Require:

- Slurm `COMPLETED`, exit `0:0`.
- Report ends with successful allele tagging and sorting.
- Pair categories sum exactly to the uniquely mapped STAR read-pair count:
  `unassigned + genome1 + genome2 + conflicting`.
- N-masked positions found in the SNP list should be nearly complete; a large mismatch suggests chromosome naming or build mismatch.
- Confirm maternal/paternal symlinks agree with the explicit mother and the invariant `G1=BDF1`, `G2=CAST`.

Many unassigned reads are expected because only reads overlapping informative SNPs can be phased.

## featureCounts

Require:

- Slurm `COMPLETED`, exit `0:0`.
- Log says `Allelic gene counting completed successfully`.
- These files exist and are non-empty:
  - `<SAMPLE>.allelic.featureCounts.txt`
  - `<SAMPLE>.allelic.featureCounts.txt.summary`
  - `<SAMPLE>.maternal_paternal_counts.tsv`
  - `<SAMPLE>.featureCounts_run_info.txt`
- The simplified table columns are:
  `Geneid`, `Maternal_count`, `Paternal_count`, `Allelic_total`, `Maternal_fraction`, `Paternal_fraction`.

Counts are paired-end fragments assigned to genes from already phased BAMs. A zero on one allele is not by itself proof of monoallelic expression. For allele-bias tests, apply an explicit minimum allelic coverage such as `Allelic_total >= 10` and use biological replicates/statistical testing.
