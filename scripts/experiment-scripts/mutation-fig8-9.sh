#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 8-9 from the GRT paper.
# It executes `mutation.sh` multiple times, varying:
#   - Subject programs (PROGRAMS)
#   - Feature variants (FEATURES)
#   - Total execution time (TOTAL_TIME)
#
# Note: Figure 10 could not be generated because we weren't able to locate
# the subject program scch-collection-1.0
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
# Please run this script from the experiment-scripts/ directory.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   ./mutation-fig8-9.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.
#
#===============================================================================

# Clean up previous run artifacts
rm -rf build/bin/*
rm -rf build/test/*
rm -rf build/lib/*
rm -rf results/*

MUTATION_DIR="$(realpath ../)"

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
PROGRAMS=(all 30 subject programs)
FEATURES=(CONSTANT_MINING GRT_FUZZING ELEPHANT_BRAIN DETECTIVE ORIENTEERING BLOODHOUND GRT)

# Temporary parameters for testing that override the defaults, since we haven't
# implemented all GRT features. See mutation.sh for a list of different features
# you can specify.
NUM_LOOP=3
TOTAL_TIME=(100 200 300 400 500 600)
PROGRAMS=(
  "asm-5.0.1"
  "tiny-sql-2.26"
)
FEATURES=(
  "BLOODHOUND"
  "ORIENTEERING"
)

NUM_CORES=$(($(nproc) - 4))
echo "Running $NUM_CORES concurrent processes"

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for time in "${TOTAL_TIME[@]}"; do
  for program in "${PROGRAMS[@]}"; do
    for feature in "${FEATURES[@]}"; do
      TASKS+=("$time $program $feature")
    done
  done
done

# Export function for parallel execution
# Each run's output is redirected to mutation_output.txt within its respective results directory.
run_task() {
  time=$1
  program=$2
  feature=$3
  echo "Running: (cd $MUTATION_DIR && ./mutation.sh -t $time -f $feature -r -n $NUM_LOOP $program)"
  (cd "$MUTATION_DIR" && ./mutation.sh -t "$time" -f "$feature" -r -n "$NUM_LOOP" "$program")
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation (Fig. 8 and 9)
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
"$PYTHON_EXECUTABLE" "$MUTATION_DIR"/experiment-scripts/generate-figures.py fig8-9
