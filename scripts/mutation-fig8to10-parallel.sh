#!/bin/bash

################################################################################
#
# This script runs mutation-unit.sh in parallel on the Cartesian product of
# PROGRAMS, and GENERATORS to generate Figure 7 of the GRT paper
#
# The degree of parallelism is hard-coded as NUM_CORES. Modify this as needed.
#
################################################################################

# Define parameters
TIME_LIMIT=(50)
PROGRAMS=(
  "tinySQL-2.26"
)
GENERATORS=(
  "randoopGRTMinusDynamicTyping"
)

# Number of compute cores
# NUM_CORES=$(($(nproc) / 2))
NUM_CORES=$(($(nproc) - 4))
echo "Running on at most $NUM_CORES concurrent processes"

# Create a list of tasks
TASKS=()
for seconds in "${TIME_LIMIT[@]}"; do
  for program in "${PROGRAMS[@]}"; do
    for generator in "${GENERATORS[@]}"; do
      TASKS+=("$seconds $program $generator")
    done
  done
done

# Export function for parallel execution
run_task() {
  seconds=$1
  program=$2
  generator=$3
  # Use the same unit script as fig7
  echo "Running: ./mutation-fig7-unit.sh -t $seconds -g $generator $program"
  ./mutation-fig7-unit.sh -t "$seconds" -g "$generator" "$program"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task
