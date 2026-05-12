#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: docker run --rm -it -p 3838:3838 -v <data-dir>:/data <image> <seurat.rds|seurat.rds.gz>" >&2
  exit 2
fi

input="$1"

if [ "${input#/}" = "$input" ]; then
  input="/data/${input}"
fi

if [ ! -f "$input" ]; then
  echo "Input file not found: $input" >&2
  exit 1
fi

case "$input" in
  *.rds|*.rds.gz) ;;
  *)
    echo "Input must be a .rds or .rds.gz file: $input" >&2
    exit 1
    ;;
esac

exec Rscript /usr/local/bin/run_shinycell.R "$input"
