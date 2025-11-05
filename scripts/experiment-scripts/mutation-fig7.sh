#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 7 from the GRT paper.
# It executes `mutation-randoop.sh` multiple times, varying:
#   - Subject programs (SUBJECT_PROGRAMS)
#   - Feature variants (FEATURES)
#
#===============================================================================
# Output
#===============================================================================
# `results/fig7.csv`: Raw data appended to by `mutation-randoop.sh`.
# `results/fig7.pdf`: Figure 7, generated from `results/fig7.csv`.
#
#===============================================================================
# Important Notes
#===============================================================================
# This script overwrites previous output (results/fig7.pdf and results/fig7.csv).
# If you wish to preserve previous files, **download or back it up before
# re-running this script**.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   mutation-fig7.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.
#
#===============================================================================

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
GRT_TESTING_ROOT="$(realpath "$SCRIPT_DIR"/../)"

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

pip install pandas
pip install matplotlib
pip install seaborn

# Clean up previous run artifacts
make -C "$GRT_TESTING_ROOT" clean
rm -f "$GRT_TESTING_ROOT"/results/fig7.pdf
rm -f "$GRT_TESTING_ROOT"/results/fig7.csv

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
TOTAL_SECONDS=(600)
. "$SCRIPT_DIR"/set-subject-programs.sh
FEATURES=(CONSTANT_MINING GRT_FUZZING ELEPHANT_BRAIN DETECTIVE ORIENTEERING BLOODHOUND GRT)

# Temporary parameters for testing that override the defaults, since we haven't
# implemented all GRT features. See mutation-randoop.sh for the list of features.
NUM_LOOP=1
TOTAL_SECONDS=(10)
SUBJECT_PROGRAMS=(
  "dcParseArgs-10.2008"
  "nekomud-r16"
)
FEATURES=(
  "BLOODHOUND"
  "ORIENTEERING"
)

NUM_CORES=$(($(nproc) - 4))
echo "$(basename "$0"): Running $NUM_CORES concurrent processes."

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
    echo "Running (GRT): mutation-randoop.sh -t $tseconds -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig7.csv $program"
    "$GRT_TESTING_ROOT"/mutation-randoop.sh -t "$tseconds" -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig7.csv "$program"
  else
    # `mutation-randoop.sh` checks the validity of $feature.
    echo "Running: mutation-randoop.sh -t $tseconds -f $feature -r -o fig7.csv $program"
    "$GRT_TESTING_ROOT"/mutation-randoop.sh -t "$tseconds" -f "$feature" -r -o fig7.csv "$program"
  fi
}

export -f run_task

# Run all tasks in parallel.
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation
#===============================================================================

"$PYTHON_EXECUTABLE" "$GRT_TESTING_ROOT"/experiment-scripts/generate-grt-figures.py fig7
