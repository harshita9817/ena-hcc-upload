#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from pathlib import Path


def load_manifest(path: Path) -> dict[str, str]:
    md5_by_name: dict[str, str] = {}
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"filename", "md5"}
        if not reader.fieldnames or not required.issubset(reader.fieldnames):
            raise SystemExit(
                f"Manifest must contain columns {sorted(required)}; got {reader.fieldnames}"
            )
        for row in reader:
            name = row["filename"].strip()
            md5 = row["md5"].strip()
            if name in md5_by_name and md5_by_name[name] != md5:
                raise SystemExit(f"Conflicting MD5 values for {name}")
            md5_by_name[name] = md5
    return md5_by_name


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: fill_webin_md5s.py <input_webin_tsv> <md5_manifest_tsv> <output_webin_tsv>",
            file=sys.stderr,
        )
        return 1

    input_tsv = Path(sys.argv[1])
    manifest_tsv = Path(sys.argv[2])
    output_tsv = Path(sys.argv[3])

    md5_by_name = load_manifest(manifest_tsv)

    with input_tsv.open(newline="") as src:
        rows = list(csv.reader(src, delimiter="\t"))

    if len(rows) < 3:
        raise SystemExit("Input Webin TSV is shorter than expected")

    missing: list[str] = []

    for row in rows[2:]:
        if len(row) < 12:
            raise SystemExit(f"Row has too few columns: {row}")

        forward_name = row[8].strip()
        reverse_name = row[10].strip()

        if forward_name not in md5_by_name:
            missing.append(forward_name)
        else:
            row[9] = md5_by_name[forward_name]

        if reverse_name not in md5_by_name:
            missing.append(reverse_name)
        else:
            row[11] = md5_by_name[reverse_name]

    if missing:
        unique_missing = sorted(set(missing))
        raise SystemExit(
            "Missing MD5 entries for:\n" + "\n".join(unique_missing)
        )

    with output_tsv.open("w", newline="") as dst:
        writer = csv.writer(dst, delimiter="\t", lineterminator="\n")
        writer.writerows(rows)

    print(f"Wrote updated Webin TSV: {output_tsv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
