#!/bin/bash

# Move all untracked files in the scripts/ directory to a temp/ directory.
# This script is useful when you want to clean up the scripts/ directory
# as running mutation scripts may create many new files due to execution of
# subject programs.

# Change to the directory this script resides in.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir" || exit 1

echo "Cleaning scripts/ directory..."
mkdir -p temp

echo "Moving untracked *files* in the top-level to temp/"

# Use Git to list untracked files (null-delimited) and process each.
git ls-files --others --exclude-standard -z . | while IFS= read -r -d '' path; do
  if [[ "$path" == *"/"* ]] || [[ "$path" == temp/* ]]; then
    continue
  fi

  echo "Moving file: $path"
  mv -- "$path" temp/
done

echo "Done. Untracked files have been moved to temp/."
