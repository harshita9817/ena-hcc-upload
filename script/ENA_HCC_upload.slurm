#!/usr/bin/bash
# Example Slurm script for uploading ENA FASTQ files from an HPC system using lftp.
# Update the SBATCH settings and the configurable variables below for your cluster.

#SBATCH --job-name=ena_upload
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=60:00:00
#SBATCH --partition=batch
#SBATCH --output=logs/%x.out
#SBATCH --error=logs/%x.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your_email@example.edu
#SBATCH --chdir=/path/to/your/fastq_root

set -euo pipefail

mkdir -p logs

# Credentials file should define WEBIN_USER and WEBIN_PASS, for example:
# export WEBIN_USER='Webin-XXXXX'
# export WEBIN_PASS='your_password_here'
source /path/to/your/fastq_root/.webin_env

module load lftp

# Root directory containing FASTQ files, potentially in nested subfolders.
FASTQ_DIR="/path/to/your/fastq_root"

# Read-submission TSV with forward/reverse FASTQ file names in columns 9 and 11.
TSV="/path/to/your/read_submission.tsv"

if [ ! -d "$FASTQ_DIR" ]; then
  echo "Missing FASTQ directory: $FASTQ_DIR" >&2
  exit 1
fi

if [ ! -f "$TSV" ]; then
  echo "Missing TSV: $TSV" >&2
  exit 1
fi

mapfile -t names < <(
  awk -F '\t' '
    NR <= 2 { next }
    { print $9; print $11 }
  ' "$TSV" | sort -u
)

if [ ${#names[@]} -eq 0 ]; then
  echo "No FASTQ names found in TSV" >&2
  exit 1
fi

echo "Found ${#names[@]} FASTQ files to upload"

count=0
for name in "${names[@]}"; do
  file="$(find "$FASTQ_DIR" -type f -name "$name" | head -n 1)"

  if [ -z "$file" ]; then
    echo "Could not find file for TSV entry: $name" >&2
    exit 1
  fi

  count=$((count + 1))
  echo "Uploading file ${count}/${#names[@]}: $file"

  lftp -u "$WEBIN_USER","$WEBIN_PASS" webin2.ebi.ac.uk -e "set ssl:verify-certificate no; set xfer:clobber on; put \"$file\"; bye"

  echo "Completed upload: $file"
done

echo "All uploads finished."
