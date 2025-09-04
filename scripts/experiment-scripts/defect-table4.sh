#!/bin/bash

#===============================================================================
# Overview
#===============================================================================
# This script generates Table 4 from the GRT paper.
# It executes `defect-randoop.sh` and `defect-evosuite.sh` multiple times, varying:
#   - Projects (PROJECT-ID)
#   - Total execution time (TOTAL_TIME)
#
#===============================================================================
# Output
#===============================================================================
# `results/table4.csv`: Raw data appended to by `defect-randoop.sh` and `defect-evosuite.sh`.
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
#   defect-table4.sh
#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `defect-prerequisites.md`.
#
#===============================================================================

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
DEFECT_DIR="$(realpath "$SCRIPT_DIR"/../)"

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 1
fi

pip install pandas
pip install matplotlib
pip install seaborn

# Clean up previous run artifacts
rm -rf "$DEFECT_DIR"/build/defects4j-src/*
rm -rf "$DEFECT_DIR"/build/randoop-tests/*
rm -rf "$DEFECT_DIR"/build/evosuite-tests/*
rm -rf "$DEFECT_DIR"/build/evosuite-report/*
rm -f "$DEFECT_DIR"/results/table4.pdf
rm -f "$DEFECT_DIR"/results/table4.csv

#===============================================================================
# The GRT paper's parameters are as follows:
NUM_LOOP=10
TOTAL_SECONDS=(120 300 600)
PROJECT_IDS=("Chart" "Math" "Time" "Lang")
MODES=(BASELINE GRT EVOSUITE)
declare -A BUG_IDS

# Temporary parameters for testing that override the defaults (GRT has not been finished yet)
NUM_LOOP=1
TOTAL_SECONDS=(10)
PROJECT_IDS=("Lang")
MODES=(BASELINE EVOSUITE)
BUG_IDS["Lang"]="1 3"

NUM_CORES=$(($(nproc) - 4))
echo "$(basename "$0"): Running $NUM_CORES concurrent processes."

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
      for mode in "${MODES[@]}"; do
        for _ in $(seq 1 "$NUM_LOOP"); do
          TASKS+=("$DEFECT_DIR $tseconds $project $bug_id $mode")
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
  DEFECT_DIR=$1
  tseconds=$2
  project=$3
  bug_id=$4
  mode=$5
  if [ "$mode" == "EVOSUITE" ]; then
    echo "Running: defect-evosuite.sh -t $tseconds -b $bug_id -r -o table4.csv $project"
    "$DEFECT_DIR"/defect-evosuite.sh -t "$tseconds" -b "$bug_id" -r -o table4.csv "$project"
  elif [ "$mode" == "GRT" ]; then
    echo "Running (GRT): defect-randoop.sh -t $tseconds -b $bug_id -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o table4.csv $project"
    "$DEFECT_DIR"/defect-randoop.sh -t "$tseconds" -b "$bug_id" -f BLOODHOUND,ORIENTEERING,DETECTIVE,GRT_FUZZING,ELEPHANT_BRAIN,CONSTANT_MINING -r -o table4.csv "$project"
  elif [ "$mode" == "BASELINE" ]; then
    echo "Running (Baseline): defect-randoop.sh -t $tseconds -b $bug_id -r -o table4.csv $project"
    "$DEFECT_DIR"/defect-randoop.sh -t "$tseconds" -b "$bug_id" -r -o table4.csv "$project"
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

"$PYTHON_EXECUTABLE" "$DEFECT_DIR"/experiment-scripts/generate-grt-figures.py table4
