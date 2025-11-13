#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Table 4 from the GRT paper.
# It executes `defects4j-randoop.sh` and `defects4j-evosuite.sh` multiple times, varying:
#   - Projects (PROJECT-ID)
#   - Total execution time (TOTAL_TIME)
#
#===============================================================================
# Output
#===============================================================================
# `results/table4.csv`: Raw data appended to by `defects4j-randoop.sh` and `defects4j-evosuite.sh`.
# `results/table4.pdf`: Table 4, generated from `results/table4.csv`.
#
#===============================================================================
# Important Notes
#===============================================================================
# This script overwrites previous output (results/table4.pdf and results/table4.csv).
# If you wish to preserve previous files, **download or back it up before
# re-running this script**.
#
#------------------------------------------------------------------------------
# Usage:
#------------------------------------------------------------------------------
#   defects4j-table4.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `prerequisites.md`.
#
#===============================================================================

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
SCRIPT_NAME=$(basename -- "$0")
GRT_TESTING_ROOT="$(realpath "$SCRIPT_DIR"/../)"

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

# Clean up previous run artifacts
rm -rf "$GRT_TESTING_ROOT"/build/defects4j-src/*
rm -rf "$GRT_TESTING_ROOT"/build/randoop-tests/*
rm -rf "$GRT_TESTING_ROOT"/build/evosuite-tests/*
rm -rf "$GRT_TESTING_ROOT"/build/evosuite-report/*
rm -f "$GRT_TESTING_ROOT"/results/table4.pdf
rm -f "$GRT_TESTING_ROOT"/results/table4.csv

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
TOTAL_SECONDS=(120 300 600)
PROJECT_IDS=("Chart" "Math" "Time" "Lang")
TEST_GENERATORS=(BASELINE GRT EVOSUITE)
declare -A BUG_IDS

# Temporary parameters for testing that override the defaults (GRT has not been finished yet)
NUM_LOOP=1
TOTAL_SECONDS=(10)
PROJECT_IDS=("Lang")
TEST_GENERATORS=(BASELINE EVOSUITE)
BUG_IDS["Lang"]="1 3"

if command -v nproc > /dev/null 2>&1; then
  NPROC=$(nproc)
elif command -v getconf > /dev/null 2>&1; then
  NPROC=$(getconf _NPROCESSORS_ONLN)
else
  NPROC=1
fi
NUM_CORES=$((NPROC - 4))
if [ "$NUM_CORES" -lt 1 ]; then NUM_CORES=1; fi
echo "${SCRIPT_NAME}: Running $NUM_CORES concurrent processes."

#===============================================================================
# Task Generation & Execution
#===============================================================================
get_bug_ids() {
  local project_id="$1"
  if [[ -n "${BUG_IDS[$project_id]}" ]]; then
    echo "${BUG_IDS[$project_id]}"
  else
    defects4j query -p "$project_id"
  fi
}

TASKS=()
for tseconds in "${TOTAL_SECONDS[@]}"; do
  for project in "${PROJECT_IDS[@]}"; do
    for bug_id in $(get_bug_ids "$project"); do
      for test_generator in "${TEST_GENERATORS[@]}"; do
        for _ in $(seq 1 "$NUM_LOOP"); do
          TASKS+=("$GRT_TESTING_ROOT $tseconds $project $bug_id $test_generator")
        done
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
  project=$3
  bug_id=$4
  test_generator=$5
  if [ "$test_generator" == "EVOSUITE" ]; then
    echo "Running: defects4j-evosuite.sh -t $tseconds -b $bug_id -r -o table4.csv $project"
    "$GRT_TESTING_ROOT"/defects4j-evosuite.sh -t "$tseconds" -b "$bug_id" -r -o table4.csv "$project"
  elif [ "$test_generator" == "GRT" ]; then
    echo "Running (GRT): defects4j-randoop.sh -t $tseconds -b $bug_id -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o table4.csv $project"
    "$GRT_TESTING_ROOT"/defects4j-randoop.sh -t "$tseconds" -b "$bug_id" -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o table4.csv "$project"
  elif [ "$test_generator" == "BASELINE" ]; then
    echo "Running (Baseline): defects4j-randoop.sh -t $tseconds -b $bug_id -r -o table4.csv $project"
    "$GRT_TESTING_ROOT"/defects4j-randoop.sh -t "$tseconds" -b "$bug_id" -r -o table4.csv "$project"
  else
    echo "Invalid test generator $test_generator. Please use GRT, EVOSUITE, or BASELINE."
  fi
}

export -f run_task

# Run all tasks in parallel.
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation
#===============================================================================

"$PYTHON_EXECUTABLE" "$GRT_TESTING_ROOT"/experiment-scripts/generate-grt-figures.py table4
