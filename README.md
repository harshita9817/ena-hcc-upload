# ENA Upload Workflow From HCC

This repository contains a practical workflow for submitting paired-end RNA-seq FASTQ files to ENA using:

- ENA Webin for metadata and read submission
- an HPC system for file transfer
- `lftp` for upload
- MD5 checksum generation from the exact FASTQ files listed in the ENA read-submission TSV

## Repository Layout

```text
github_repo_template/
├── README.md
├── .gitignore
├── .webin_env.example
├── scripts/
│   ├── ENA_HCC_upload.slurm
│   ├── generate_md5_manifest_from_tsv.sh
│   └── fill_webin_md5s.py
└── templates/
    └── Webin_fastq2_read_submission_example.tsv
```

## Prerequisites

Before using this workflow:

1. Register your study in ENA.
2. Register your samples in ENA, or confirm that sample accessions already exist.
3. Upload your FASTQ files into the ENA Webin upload area.
4. Prepare a read-submission TSV using the ENA paired FASTQ template.

## High-Level Workflow

### 1. Prepare the ENA reads TSV

The ENA paired FASTQ template should look like:

- line 1: `FileType	fastq	Read submission file type`
- line 2: header row with:
  - `sample`
  - `study`
  - `instrument_model`
  - `library_name`
  - `library_source`
  - `library_selection`
  - `library_strategy`
  - `library_layout`
  - `forward_file_name`
  - `forward_file_md5`
  - `reverse_file_name`
  - `reverse_file_md5`

Use the example in `templates/Webin_fastq2_read_submission_example.tsv` as a starting point.

### 2. Create the Webin credentials file on the HPC system

Create a file named `.webin_env` in your working directory:

```bash
export WEBIN_USER='Webin-XXXXX'
export WEBIN_PASS='your_password_here'
```

Protect it:

```bash
chmod 600 .webin_env
```

Do not commit the real `.webin_env` file to Git.

### 3. Upload the FASTQ files from HPC

Update `scripts/ENA_HCC_upload.slurm` with:

- your cluster `#SBATCH` settings
- your FASTQ root directory
- the path to your read-submission TSV

Then submit:

```bash
sbatch scripts/ENA_HCC_upload.slurm
```

This script:

- reads forward and reverse FASTQ names from the TSV
- finds those files under the FASTQ root
- uploads them sequentially with `lftp`

### 4. Generate MD5 checksums for the exact TSV FASTQs

Run on the HPC system:

```bash
bash scripts/generate_md5_manifest_from_tsv.sh \
  /path/to/fastq_root \
  /path/to/read_submission.tsv \
  /path/to/md5_manifest.tsv
```

This produces a manifest with:

- `filename`
- `md5`
- `full_path`

### 5. Fill the MD5 columns in the ENA reads TSV

Run locally or wherever the TSV is stored:

```bash
python3 scripts/fill_webin_md5s.py \
  /path/to/read_submission.tsv \
  /path/to/md5_manifest.tsv \
  /path/to/read_submission_with_md5.tsv
```

### 6. Submit the final TSV in ENA

In ENA Webin:

1. Go to `Raw Reads`
2. Click `Submit Reads`
3. Upload the final TSV with real MD5 values

After submission, check:

- `Runs Report`
- `Run Files Report`
- `Run Processing Report`

## Notes

- ENA `Unsubmitted Files Report` can contain stale `.partial` upload records from failed transfers.
- A `.partial` file is not necessarily a problem if the real non-partial file was later uploaded successfully.
- Compare ENA file sizes against local/HPC file sizes if you need to distinguish complete uploads from stale partials.

## Security

- Do not commit real Webin usernames and passwords.
- Do not commit private metadata unless you intend to publish it.
- Keep `.webin_env` out of version control.
