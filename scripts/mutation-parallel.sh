#===============================================================================
# Description:
# This script serves as a wrapper for executing the `mutation.sh` script across 
# a variety of configurations in parallel. Specifically, it runs `mutation.sh` 
# with different combinations of:
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
# Purpose:
# The primary goal is to efficiently execute multiple mutation analysis tasks 
# and store their outputs for further evaluation. The results collected in 
# results/info.csv will be used for generating:
#   - Table 3
#   - Figure 6
#   - Figure 7
# as described in the GRT paper.
#
#===============================================================================

# Clean up previous run artifacts
rm -rf build/bin/*
rm -rf build/test/*
rm -rf build/lib/*
rm -rf results/*

#===============================================================================
# Parameters (Feel free to change as you wish. This is minimal just for testing purposes)
#===============================================================================
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
      TASKS+=("$seconds $program $feature")
    done
  done
done

# Export function for parallel execution
run_task() {
  seconds=$1
  program=$2
  feature=$3
  echo "Running: ./mutation.sh -c $seconds -f $feature $program"
  ./mutation.sh -c "$seconds" -f "$feature" -r "$program"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task

#===============================================================================
# Figure Generation
#===============================================================================

