#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Figure 7 from the GRT paper.
# It executes `mutation.sh` multiple times, varying:
#   - Subject programs (SUBJECT_PROGRAMS)
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
#   ./mutation-fig7.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.
#
#===============================================================================

SCRIPTDIR="$(cd "$(dirname "$0")" > /dev/null 2>&1 && pwd -P)"
cd "$SCRIPTDIR" || exit 2
MUTATION_DIR="$(realpath ../)"

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

pip install pandas
pip install matplotlib
pip install seaborn

# Clean up previous run artifacts
rm -rf build/bin/*
rm -rf build/test/*
rm -rf build/lib/*
rm -rf results/*

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
TOTAL_SECONDS=(600)
SUBJECT_PROGRAMS=(all 30 subject programs)
FEATURES=(CONSTANT_MINING GRT_FUZZING ELEPHANT_BRAIN DETECTIVE ORIENTEERING BLOODHOUND GRT)

# Temporary parameters for testing that override the defaults, since we haven't
# implemented all GRT features. See mutation.sh for a list of different features
# you can specify.
NUM_LOOP=3
SUBJECT_PROGRAMS=(
  "dcParseArgs-10.2008"
  "slf4j-api-1.7.12"
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
for tseconds in "${TOTAL_SECONDS[@]}"; do
  for program in "${SUBJECT_PROGRAMS[@]}"; do
    for feature in "${FEATURES[@]}"; do
      TASKS+=("$tseconds $program $feature")
    done
  done
done

# Export function for parallel execution
# Each run's output is redirected to mutation_output.txt within its respective results directory.
run_task() {
  tseconds=$1
  program=$2
  feature=$3
  echo "Running: (cd $MUTATION_DIR && ./mutation.sh -t $tseconds -f $feature -r -n $NUM_LOOP $program)"
  (cd "$MUTATION_DIR" && ./mutation.sh -t "$tseconds" -f "$feature" -r -n "$NUM_LOOP" "$program")
}

export -f run_task

# Run tasks in parallel.
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation (Fig. 7)
#===============================================================================

# Outputs figures to result/report.pdf
"$PYTHON_EXECUTABLE" "$MUTATION_DIR"/experiment-scripts/generate-figures.py fig7
