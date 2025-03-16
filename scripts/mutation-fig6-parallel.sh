#!/bin/bash

################################################################################
#
# This script runs mutation-unit.sh in parallel on the Cartesian product of
# SECONDS_PER_CLASS, PROGRAMS, and GENERATORS to generate Figure 6 and Table III
# of the GRT paper
#
# The degree of parallelism is hard-coded as NUM_CORES. Modify this as needed.
#
################################################################################

# Define parameters
SECONDS_PER_CLASS=(2 10 30 60)
PROGRAMS=(
  "a4j-1.0b"
  "commons-lang3-3.0"
  "jvc-1.1"
  "JSAP-2.1"
  "dcParseArgs-10.2008"
  "easymock-3.2"
  "fixsuite-r48"
  "javassist-3.19"
  "jdom-1.0"
  "commons-collections4-4.0"
  "jaxen-1.1.6"
  "joda-time-2.3"
  "slf4j-api-1.7.12"
)
GENERATORS=(
  "evosuite"
  "randoop"
  "randoopGRTMinusDynamicTyping"
  "randoopGRTMinusInputConstruction"
  "randoopGRTMinusMinCostFirst"
  "randoopGRTMinusMinCoverageFirst"
  "randoopGRT"
)

# Number of compute cores
# NUM_CORES=$(($(nproc) / 2))
NUM_CORES=$(( $(nproc) - 4 ))
echo "Running on at most $NUM_CORES concurrent processes"

# Create a list of tasks
TASKS=()
for seconds in "${SECONDS_PER_CLASS[@]}"; do
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
    echo "Running: ./mutation-fig6-unit.sh -c $seconds -g $generator $program"
    ./mutation-fig6-unit.sh -c "$seconds" -g "$generator" "$program"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task