#!/bin/sh

# This script clones the repositories for each subject program, in
# subject-programs/src/. If the repository already exists, it pulls the
# latest changes.

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"

set -e

SUBJECT_GRT_SRC_DIR="${SCRIPT_DIR}/../subject-programs/src-grt"
mkdir -p "${SUBJECT_GRT_SRC_DIR}"
cd "${SUBJECT_GRT_SRC_DIR}"

grt_clone() {
  printf '%s:' "$1"
  if [ -d "$1" ]; then
    echo " updating."
    (cd "$1" && git pull -q)
  else
    echo " cloning."
    git clone -q https://github.com/randoop/grt-"$1" "$1" \
      || { echo "Error: Failed to clone grt-$1. Retrying without -q..." >&2; \
           git clone https://github.com/randoop/grt-"$1" "$1"; }
  fi
}

# shellcheck disable=SC2013
for dir in $(grep "^dir:" ../build-info.yaml | sed 's/^dir: //'); do
  grt_clone "$dir"
done
