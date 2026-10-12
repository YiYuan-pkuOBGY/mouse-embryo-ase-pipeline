# Configuration

Copy `config/pipeline.env.example` to `config/pipeline.env`, fill in real server paths, and do not commit the real file. The submission wrapper loads it automatically. Alternatively set `ASE_PIPELINE_CONFIG` to an absolute configuration path.

Required settings:

```bash
PROJECT_ROOT="/path/to/ASE_test"
ASE_ENV="/path/to/conda/envs/ase"
RNASEQ_ENV="/path/to/conda/envs/rnaseq2"
STAR_INDEX="/path/to/nmasked_STAR_index"
SNP_FILE="/path/to/CAST_vs_BDF1.GRCm38.snps.chr.txt.gz"
GTF="/path/to/gencode.vM25.annotation.gtf"
SLURM_PARTITION="batch"
```

Optional settings have defaults in the example file. All paths must be server-local paths visible from compute nodes.

The established biological contract is not configurable without redesign:

```text
Genome build: mm10/GRCm38
Genome1 / REF: BDF1
Genome2 / ALT: CAST
Data: paired-end Smart-seq2/SMART-Seq RNA-seq
```

The STAR index should be built from the same N-masked FASTA and annotation used to construct the SNP workflow. A materially different read length may warrant a new index using `sjdbOverhang = read length - 1`.

After configuration, validate on the server:

```bash
bash -n scripts/run_STAR_align.slurm
bash -n scripts/run_SNPsplit.slurm
bash -n scripts/run_allelic_featureCounts.slurm
bash -n scripts/submit_ASE_pipeline.sh
```

Do not place passwords, private keys, access tokens, or SSH URLs with embedded credentials in the configuration.
