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
TIME_LIMIT=600
PROGRAMS=(
  "a4j-1.0b"                    # 45  classes
  "commons-lang3-3.0"           # 141 classes
  "jvc-1.1"                     # 24  classes
  "JSAP-2.1"                    # 69  classes
  "dcParseArgs-10.2008"         # 6   classes
  "easymock-3.2"                # 79  classes
  "fixsuite-r48"                # 36  classes
  "javassist-3.19"              # 367 classes
  "jdom-1.0"                    # 70  classes
  "commons-collections4-4.0"    # 390 classes
  "jaxen-1.1.6"                 # 175 classes
  "joda-time-2.3"               # 208 classes
  "slf4j-api-1.7.12"            # 18 classes
)
GENERATORS=(
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
for program in "${PROGRAMS[@]}"; do
    for generator in "${GENERATORS[@]}"; do
        TASKS+=("$program $generator")
    done
done

# Export function for parallel execution
run_task() {
    program=$1
    generator=$2
    echo "Running: ./mutation-fig7-unit.sh -t $TIME_LIMIT -g $generator $program"
    ./mutation-fig7-unit.sh -t "$TIME_LIMIT" -g "$generator" "$program"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task