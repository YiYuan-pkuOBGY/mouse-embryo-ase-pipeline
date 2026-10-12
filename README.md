# Mouse Embryo ASE Pipeline Skill

A Skill and Slurm workflow for paired-end CAST/EiJ–B6D2F1 mouse embryo Smart-seq2 allele-specific RNA-seq on mm10/GRCm38.

It runs:

```text
clean FASTQ -> N-masked STAR -> SNPsplit -> maternal/paternal featureCounts
```

## Configure

Copy `config/pipeline.env.example` to `config/pipeline.env` on the server and replace every `/path/to/...` value. Do not commit the real configuration.

After cloning or installing the Skill, run the following commands on the Linux/Slurm server:

```bash
cd /path/to/mouse-embryo-ase-pipeline

cp config/pipeline.env.example config/pipeline.env

nano config/pipeline.env
```

Fill in the project root, Conda environments, N-masked STAR index, informative SNP file, GTF and Slurm partition. Then add execution permissions and validate all Bash scripts before submitting data:

```bash
chmod +x \
  scripts/run_STAR_align.slurm \
  scripts/run_SNPsplit.slurm \
  scripts/run_allelic_featureCounts.slurm \
  scripts/submit_ASE_pipeline.sh

bash -n scripts/run_STAR_align.slurm
bash -n scripts/run_SNPsplit.slurm
bash -n scripts/run_allelic_featureCounts.slurm
bash -n scripts/submit_ASE_pipeline.sh
```

All four `bash -n` commands must finish without output and return exit status `0`:

```bash
echo $?
```

Do not continue to sample submission until the configuration paths exist on the compute nodes and all syntax checks pass.

The SNP contract is fixed:

```text
Genome1 / REF = BDF1
Genome2 / ALT = CAST
```

## Submit

```bash
bash scripts/submit_ASE_pipeline.sh SAMPLE R1.fastq.gz R2.fastq.gz BDF1
```

The last argument is the actual maternal strain: `BDF1` or `CAST`.

The final table is written to:

```text
${PROJECT_ROOT}/gene_counts/${SAMPLE}/${SAMPLE}.maternal_paternal_counts.tsv
```

This repository does not include reference genomes, STAR indexes, VCFs, FASTQs, BAMs, credentials, or Conda environments.
