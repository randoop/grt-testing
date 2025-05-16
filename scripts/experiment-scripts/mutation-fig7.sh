#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script is designed to efficiently generate Figure 7 from the
# GRT paper by executing multiple configurations of the `mutation.sh` script in
# parallel. It automates the collection of experimental data by varying:
#   - Subject programs (PROGRAMS)
#   - Feature variants (FEATURES)
#
# To maximize efficiency, the script leverages GNU Parallel, distributing the
# workload across available CPU cores.
#
# Each invocation of `mutation.sh` appends its results to `results/info.csv`,
# which serves as the basis for constructing Figure 7.
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
#   ./mutation-fig7.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See the file `mutation-prerequisites.md` for details on required setup.
#
#===============================================================================

# Clean up previous run artifacts
rm -rf build/bin/*
rm -rf build/test/*
rm -rf build/lib/*
rm -rf results/*

MUTATION_DIR="$(realpath ../)"

#===============================================================================
# Parameters (Feel free to change as you wish. What I have is just for testing purposes)
# The papers' parameters should be as follows:
# NUM_LOOP = 10
# PROGRAMS = (all 30 subject programs)
# FEATURES = (CONSTANT_MINING GRT_FUZZING ELEPHANT_BRAIN DETECTIVE ORIENTEERING BLOODHOUND GRT)

# Since we haven't implemented all GRT features, for now I just replaced this with whatever we currently have
# (ORIENTEERING and BLOODHOUND).
#===============================================================================
NUM_LOOP=3
PROGRAMS=(
  "dcParseArgs-10.2008"
  "slf4j-api-1.7.12"
)
FEATURES=(
  "BLOODHOUND"
  "ORIENTEERING"
)

NUM_CORES=$(($(nproc) - 4))
echo "Running on at most $NUM_CORES concurrent processes"

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for program in "${PROGRAMS[@]}"; do
  for feature in "${FEATURES[@]}"; do
    TASKS+=("$program $feature")
  done
done

# Export function for parallel execution
# Each run's output is redirected to mutation_output.txt within its respective results directory.
run_task() {
  program=$1
  feature=$2
  echo "Running: (cd $MUTATION_DIR && ./mutation.sh -t 600 -f $feature -r -n $NUM_LOOP $program)"
  (cd "$MUTATION_DIR" && ./mutation.sh -t 600 -f "$feature" -r -n "$NUM_LOOP" "$program")
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation (Fig. 7)
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
"$PYTHON_EXECUTABLE" "$MUTATION_DIR"/experiment-scripts/generate-figures.py fig7
