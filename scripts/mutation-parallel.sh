#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script serves as a wrapper for executing the `mutation.sh` script across 
# a variety of configurations in parallel. Specifically, it runs `mutation.sh` 
# with different user-configured (see below) combinations of:
#   - Execution time per class (SECONDS_PER_CLASS)
#   - Subject programs (PROGRAMS)
#   - Feature variants (FEATURES)
#
# These tasks are executed concurrently using GNU Parallel, with the number of 
# cores limited to (total cores - 4) to avoid system overload.
#
# The script assumes the following:
#   - mutation.sh exists in the same directory and is executable.
#   - Each run of mutation.sh appends results to results/info.csv.
#
# The results collected in results/info.csv are then used to generate:
#   - Table 3
#   - Figure 6
# as described in the GRT paper.
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   ./mutation-parallel.sh
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

#===============================================================================
# Parameters (Feel free to change as you wish. This is minimal just for testing purposes)
# The papers' parameters are as follows:
# NUM_LOOP = 10
# SECONDS_PER_CLASS = (2 10 30 60)
# PROGRAMS = (all 30 subject programs)
# FEATURES = (BASELINE GRT EVOSUITE)

# Since we haven't implemented all GRT features, for now I just replaced this with individual GRT features
# like BLOODHOUND. See mutation.sh for a list of different features you can specify.
#===============================================================================
NUM_LOOP=3
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
echo "Running on at most $NUM_CORES concurrent processes"

#===============================================================================
# Task Generation & Execution
#===============================================================================
TASKS=()
for seconds in "${SECONDS_PER_CLASS[@]}"; do
  for program in "${PROGRAMS[@]}"; do
    for feature in "${FEATURES[@]}"; do
      TASKS+=("$seconds $program $feature $NUM_LOOP")
    done
  done
done

# Export function for parallel execution
run_task() {
  seconds=$1
  program=$2
  feature=$3
  num_loop=$4
  echo "Running: ./mutation.sh -c $seconds -f $feature -r -n $num_loop $program"
  ./mutation.sh -c "$seconds" -f "$feature" -r -n "$num_loop" "$program"
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
"$PYTHON_EXECUTABLE" generate-figures.py