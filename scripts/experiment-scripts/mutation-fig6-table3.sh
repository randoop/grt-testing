#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 6 and Table 3 from the GRT paper.
# It executes `mutation-randoop.sh` and `mutation-evosuite.sh` multiple times, varying:
#   - Subject programs (SUBJECT_PROGRAMS)
#   - Execution time per class (SECONDS_PER_CLASS)
#
#===============================================================================
# Output
#===============================================================================
# `results/fig6-table3.csv`: Raw data appended to by `mutation-randoop.sh` and `mutation-evosuite.sh`.
# `results/fig6-table3.pdf`: Figure 6 and Table 3, generated from `results/fig6-table3.csv`.
#
#===============================================================================
# Important Notes
#===============================================================================
# This script overwrites previous output (results/fig6-table3.pdf and results/fig6-table3.csv).
# If you wish to preserve previous files, **download or back it up before
# re-running this script**.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   mutation-fig6-table3.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.
#
#===============================================================================

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
MUTATION_DIR="$(realpath "$SCRIPT_DIR"/../)"

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

pip install pandas
pip install matplotlib
pip install seaborn

# Clean up previous run artifacts
rm -rf "$MUTATION_DIR"/build/bin/*
rm -rf "$MUTATION_DIR"/build/randoop-tests/*
rm -rf "$MUTATION_DIR"/build/evosuite-tests/*
rm -rf "$MUTATION_DIR"/build/evosuite-report/*
rm -rf "$MUTATION_DIR"/build/target/*
rm -rf "$MUTATION_DIR"/build/lib/*
rm -f "$MUTATION_DIR"/results/fig6-table3.pdf
rm -f "$MUTATION_DIR"/results/fig6-table3.csv

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
SECONDS_PER_CLASS=(2 10 30 60)
. "$SCRIPT_DIR"/set-subject-programs.sh
MODES=(BASELINE GRT EVOSUITE)

# Temporary parameters for testing that override the defaults (GRT has not been finished yet)
NUM_LOOP=1
SECONDS_PER_CLASS=(2)
SUBJECT_PROGRAMS=(
  "dcParseArgs-10.2008"
  "nekomud-r16"
)
MODES=(BASELINE EVOSUITE)

NUM_CORES=$(($(nproc) - 4))
echo "$(basename "$0"): Running $NUM_CORES concurrent processes."

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for cseconds in "${SECONDS_PER_CLASS[@]}"; do
  for program in "${SUBJECT_PROGRAMS[@]}"; do
    for mode in "${MODES[@]}"; do
      for _ in $(seq 1 "$NUM_LOOP"); do
        TASKS+=("$MUTATION_DIR $cseconds $program $mode")
      done
    done
  done
done

# Function for parallel execution.
# Each time the script runs, it creates a new subdirectory under results/, e.g., results/commons-cli-1.2-BASELINE-{UUIDSEED}/.
# Each run's standard output is redirected to mutation_output.txt within its corresponding results subdirectory.
# Other related files (e.g., jacoco.exec, mutants.log, major.log) are also stored there.
run_task() {
  mutation_dir=$1
  cseconds=$2
  program=$3
  mode=$4
  if [ "$mode" == "EVOSUITE" ]; then
    echo "Running: mutation-evosuite.sh -c $cseconds -r -o fig6-table3.csv $program"
    "$mutation_dir"/mutation-evosuite.sh -c "$cseconds" -r -o fig6-table3.csv "$program"
  elif [ "$mode" == "GRT" ]; then
    echo "Running (GRT): mutation-randoop.sh -c $cseconds -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig6-table3.csv $program"
    "$mutation_dir"/mutation-randoop.sh -c "$cseconds" -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o fig6-table3.csv "$program"
  elif [ "$mode" == "BASELINE" ]; then
    echo "Running (Baseline): mutation-randoop.sh -c $cseconds -f BASELINE -r -o fig6-table3.csv $program"
    "$mutation_dir"/mutation-randoop.sh -c "$cseconds" -f BASELINE -r -o fig6-table3.csv "$program"
  else
    echo "Invalid mode $mode. Please use GRT, EVOSUITE, or BASELINE."
  fi
}

export -f run_task

# Run all tasks in parallel.
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation
#===============================================================================

"$PYTHON_EXECUTABLE" "$MUTATION_DIR"/experiment-scripts/generate-grt-figures.py fig6-table3
