#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 6 and Table 3 from the GRT paper.
# It executes `mutation.sh` multiple times, varying:
#   - Execution time per class (SECONDS_PER_CLASS)
#   - Subject programs (PROGRAMS)
#   - Feature variants (FEATURES)
#
#===============================================================================
# Output
#===============================================================================
# `results/info.csv`:   Contains raw data collected from `mutation.sh`. This file is
#                       appended to by each experimental run.
# `results/report.pdf`: Final report containing Figure 6 and Table 3, generated from
#                       `results/info.csv`.
#
#===============================================================================
# Important Notes
#===============================================================================
# Running this script will overwrite any existing contents in the `results/`
# directory, including `report.pdf`. If you wish to preserve a previous report,
# **make sure to download or back it up before running this script again**.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   ./mutation-fig6-table3.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.
#
#===============================================================================

SCRIPTDIR="$(cd "$(dirname "$0")" > /dev/null 2>&1 && pwd -P)"
cd "$SCRIPTDIR" || exit 2
MUTATION_DIR="$(realpath ../)"

# Clean up previous run artifacts
rm -rf build/bin/*
rm -rf build/test/*
rm -rf build/lib/*
rm -rf results/*

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
SECONDS_PER_CLASS=(2 10 30 60)
PROGRAMS=(all 30 subject programs)
FEATURES=(BASELINE GRT EVOSUITE)

# Temporary parameters for testing that override the defaults, since we haven't
# implemented all GRT features. See mutation.sh for a list of different features
# you can specify.
NUM_LOOP=1
SECONDS_PER_CLASS=(2)
PROGRAMS=(
  "dcParseArgs-10.2008"
  "slf4j-api-1.7.12"
)
FEATURES=(
  "BASELINE"
  "BLOODHOUND"
)

NUM_CORES=$(($(nproc) - 4))
echo "Running $NUM_CORES concurrent processes"

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for seconds in "${SECONDS_PER_CLASS[@]}"; do
  for program in "${PROGRAMS[@]}"; do
    for feature in "${FEATURES[@]}"; do
      TASKS+=("$seconds $program $feature")
    done
  done
done

# Export function for parallel execution
# Each run's output is redirected to mutation_output.txt within its respective results directory.
run_task() {
  seconds=$1
  program=$2
  feature=$3
  echo "Running: (cd $MUTATION_DIR && ./mutation.sh -c $seconds -f $feature -r -n $NUM_LOOP $program)"
  (cd "$MUTATION_DIR" && ./mutation.sh -c "$seconds" -f "$feature" -r -n "$NUM_LOOP" "$program")
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation (Table III and Fig. 6)
#===============================================================================

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

pip install pandas
pip install matplotlib
pip install seaborn

# Outputs figures to result/report.pdf
"$PYTHON_EXECUTABLE" "$MUTATION_DIR"/experiment-scripts/generate-figures.py fig6-table3
