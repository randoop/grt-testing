#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 8-9 from the GRT paper.
# It executes `mutation-randoop.sh` multiple times, varying:
#   - Subject programs (SUBJECT_PROGRAMS)
#   - Feature variants (FEATURES)
#   - Total execution time (TOTAL_TIME)
#
# Note: Figure 10 could not be generated because we weren't able to locate
# the subject program scch-collection-1.0.
#
#===============================================================================
# Output
#===============================================================================
# `results/fig8-9.csv`: Raw data appended to by `mutation-randoop.sh`.
# `results/fig8-9.pdf`: Figures 8-9, generated from `results/fig8-9.csv`.
#
#===============================================================================
# Important Notes
#===============================================================================
# This script overwrites previous output (results/fig8-9.pdf and results/fig8-9.csv).
# If you wish to preserve previous files, **download or back it up before
# re-running this script**.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   mutation-fig8-9.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `prerequisites.md`.
#
#===============================================================================

# Fail this script on errors.
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
SCRIPT_NAME=$(basename -- "$0")
GRT_TESTING_ROOT="$(realpath "$SCRIPT_DIR"/../)"

. "$SCRIPT_DIR"/common.sh

# Clean up previous run artifacts.
make -C "$GRT_TESTING_ROOT" experiment-clean
rm -f "$GRT_TESTING_ROOT"/results/fig8-9.pdf
rm -f "$GRT_TESTING_ROOT"/results/fig8-9.csv

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
TOTAL_SECONDS=(100 200 300 400 500 600)
SUBJECT_PROGRAMS=(
  "asm-5.0.1"
  "tiny-sql-2.26"
)
FEATURES=(CONSTANT_MINING GRT_FUZZING ELEPHANT_BRAIN DETECTIVE ORIENTEERING BLOODHOUND GRT)

# Temporary parameters for testing that override the defaults, since we haven't
# implemented all GRT features. See mutation-randoop.sh for the list of features.
NUM_LOOP=1
TOTAL_SECONDS=(5 10)
FEATURES=(
  "BLOODHOUND"
  "ORIENTEERING"
)

NUM_CORES=$(num_cores)
echo "${SCRIPT_NAME}: Running $NUM_CORES concurrent processes."

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for tseconds in "${TOTAL_SECONDS[@]}"; do
  for program in "${SUBJECT_PROGRAMS[@]}"; do
    for feature in "${FEATURES[@]}"; do
      for _ in $(seq 1 "$NUM_LOOP"); do
        TASKS+=("$GRT_TESTING_ROOT $tseconds $program $feature")
      done
    done
  done
done

# Function for parallel execution.
# Each time the script runs, it creates a new subdirectory under results/, e.g., results/commons-cli-1.2-BASELINE-{UUIDSEED}/.
# Each run's standard output is redirected to mutation_output.txt within its corresponding results subdirectory.
# Other related files (e.g., jacoco.exec, mutants.log, major.log) are also stored there.
run_task() {
  GRT_TESTING_ROOT=$1
  tseconds=$2
  program=$3
  feature=$4
  if [ "$feature" == "GRT" ]; then
    echo "Running (GRT): mutation-randoop.sh -t $tseconds -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig8-9.csv $program"
    "$GRT_TESTING_ROOT"/mutation-randoop.sh -t "$tseconds" -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig8-9.csv "$program"
  else
    # `mutation-randoop.sh` checks the validity of $feature.
    echo "Running: mutation-randoop.sh -t $tseconds -f $feature -r -o fig8-9.csv $program"
    "$GRT_TESTING_ROOT"/mutation-randoop.sh -t "$tseconds" -f "$feature" -r -o fig8-9.csv "$program"
  fi
}

export -f run_task

# Run all tasks in parallel.
printf "%s\n" "${TASKS[@]}" | parallel -j "$NUM_CORES" --colsep ' ' run_task

#===============================================================================
# Figure Generation
#===============================================================================

"$PYTHON_EXECUTABLE" "$GRT_TESTING_ROOT"/experiment-scripts/generate-grt-figures.py fig8-9
