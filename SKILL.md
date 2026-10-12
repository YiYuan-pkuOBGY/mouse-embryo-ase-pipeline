---
name: mouse-embryo-ase-pipeline
description: Run and troubleshoot paired-end CAST/EiJ–B6D2F1 mouse embryo Smart-seq2 allele-specific RNA-seq on a Slurm server, from clean FASTQs through N-masked STAR alignment, SNPsplit, and maternal/paternal gene counts. Use only for this established mm10/GRCm38 CAST–BDF1 workflow; other crosses or genome builds require a new reference/SNP design.
---

# Mouse embryo allele-specific RNA-seq

Turn four user inputs into a monitored Slurm workflow:

```text
SAMPLE
R1
R2
MOTHER = BDF1 or CAST
```

## Before submitting

1. Read [references/configuration.md](references/configuration.md).
2. Confirm Codex has an authorized terminal/SSH connection to the intended server. Never request, echo, or store a password in the skill.
3. Verify `R1` and `R2` exist, are paired clean FASTQs, and `MOTHER` is explicitly `BDF1` or `CAST`. Do not infer parent direction from a label such as `CastxBdf1`.
4. Verify the configured reference, SNP annotation, STAR index, GTF, environments, and worker scripts exist. Read-only checks on the login node are fine; submit compute-heavy work through Slurm.
5. Use this profile only for paired-end Smart-seq2/SMART-Seq RNA-seq from a CAST–BDF1 cross on mm10/GRCm38. Stop and redesign if the cross, genome build, sequencing layout, or reference paths differ.

## Run

Prefer the bundled [scripts/submit_ASE_pipeline.sh](scripts/submit_ASE_pipeline.sh). Deploy the bundled worker templates only when the server copies are absent or the user asks to update them:

- [scripts/run_STAR_align.slurm](scripts/run_STAR_align.slurm)
- [scripts/run_SNPsplit.slurm](scripts/run_SNPsplit.slurm)
- [scripts/run_allelic_featureCounts.slurm](scripts/run_allelic_featureCounts.slurm)

After deploying or changing any template, run `bash -n` on all four server-side scripts before submission. Preserve a working server copy unless the user authorizes replacing it.

Copy `config/pipeline.env.example` to an ignored `config/pipeline.env` once and fill in server-specific paths. For each sample, pass only `SAMPLE`, `R1`, `R2`, and `MOTHER` to the submitter. It submits STAR, SNPsplit, and featureCounts with `afterok` dependencies.

Do not report completion merely because all jobs disappeared from `squeue`. Monitor each job with `sacct`; require `COMPLETED` and `ExitCode 0:0`. If a job fails, inspect its `.out` and `.err`, diagnose the specific cause, and stop downstream interpretation.

## Non-negotiable biological mapping

The established SNP annotation defines:

```text
Genome1 / REF = BDF1
Genome2 / ALT = CAST
```

Parental origin depends only on the explicit mother:

- `MOTHER=BDF1`: Genome1 is maternal; Genome2 is paternal.
- `MOTHER=CAST`: Genome2 is maternal; Genome1 is paternal.

Never reinterpret the underlying genome1/genome2 BAMs. Only create clear maternal/paternal symlinks from this mapping.

## Completion criteria

Read [references/result-validation.md](references/result-validation.md) and verify every invariant. The primary final result is:

```text
${PROJECT_ROOT}/gene_counts/<SAMPLE>/<SAMPLE>.maternal_paternal_counts.tsv
```

Report the three Slurm job IDs, final states, maternal and paternal strain assignment, SNPsplit pair counts, featureCounts assignment summary, and the exact final path.

Clarify that counts are raw paired-end fragments assigned through informative SNPs, not TPM/FPKM and not total-gene expression.
