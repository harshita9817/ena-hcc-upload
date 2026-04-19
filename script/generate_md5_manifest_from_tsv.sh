#!/usr/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <fastq_root> <webin_tsv> <output_manifest>" >&2
  exit 1
fi

FASTQ_ROOT="$1"
WEBIN_TSV="$2"
OUT_MANIFEST="$3"

if [ ! -d "$FASTQ_ROOT" ]; then
  echo "FASTQ root does not exist: $FASTQ_ROOT" >&2
  exit 1
fi

if [ ! -f "$WEBIN_TSV" ]; then
  echo "Webin TSV does not exist: $WEBIN_TSV" >&2
  exit 1
fi

tmp_names="$(mktemp)"
trap 'rm -f "$tmp_names"' EXIT

awk -F '\t' 'FNR > 2 { print $9; print $11 }' "$WEBIN_TSV" | sort -u > "$tmp_names"

{
  printf "filename\tmd5\tfull_path\n"

  while IFS= read -r name; do
    file="$(find "$FASTQ_ROOT" -type f -name "$name" | head -n 1)"

    if [ -z "$file" ]; then
      echo "Missing FASTQ for TSV entry: $name" >&2
      exit 1
    fi

    md5="$(md5sum "$file" | awk '{print $1}')"
    printf "%s\t%s\t%s\n" "$name" "$md5" "$file"
  done < "$tmp_names"
} > "$OUT_MANIFEST"

echo "Wrote MD5 manifest: $OUT_MANIFEST"
