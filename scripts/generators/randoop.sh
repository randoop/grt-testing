#!/usr/bin/env bash
#
# Wrapper script for Randoop
#
# Environment variables: Must be set by caller script
# * JACOCO_AGENT_JAR    : Jacoco agent jar used for MinCoverageFirst
# * REPLACECALL_JAR     : Jar for replacing undesired method calls
# * REPLACECALL_COMMAND : Command invoking REPLACECALL_JAR for replacement files
# * CLASSPATH           : Dependency locations for subject program
# * SRC_JAR             : Source jar for subject program
# * GENERATOR_JAR       : Randoop jar
# * TIME_LIMIT          : Total time limit for test generation

# Check whether the ENVIRONMENT variables are set
if [ -z "$JACOCO_AGENT_JAR" ]; then
    echo "Expected JACOCO_AGENT_JAR environment variable" >&2
    set -e
fi
if [ -z "$REPLACECALL_JAR" ]; then
    echo "Expected REPLACECALL_JAR environment variable" >&2
    set -e
fi
if [ -z "$REPLACECALL_COMMAND" ]; then
    echo "Expected REPLACECALL_COMMAND environment variable" >&2
    set -e
fi
if [ -z "$CLASSPATH" ]; then
    echo "Expected CLASSPATH environment variable" >&2
    set -e
fi
if [ -z "$SRC_JAR" ]; then
    echo "Expected SRC_JAR environment variable" >&2
    set -e
fi
if [ -z "$GENERATOR_JAR" ]; then
    echo "Expected GENERATOR_JAR environment variable" >&2
    set -e
fi
if [ -z "$TIME_LIMIT" ]; then
    echo "Expected TIME_LIMIT environment variable" >&2
    set -e
fi

me=$(basename "$0")

if [[ $me != *"GRTMinusMinCoverageFirst"* && ($me == *"MinCoverageFirst"* || $me == *"GRT"*) ]]; then
    BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    METHOD_SELECTION_ARG="--method-selection=BLOODHOUND"
fi

if [[ $me != *"GRTMinusMinCostFirst"* && ($me == *"MinCostFirst"* || $me == *"GRT"*) ]]; then
    BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    INPUT_SELECTION_ARG="--input-selection=ORIENTEERING"
fi

if [[ $me != *"GRTMinusDynamicTyping"* && ($me == *"DynamicTyping"* || $me == *"GRT"*) ]]; then
    BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    RUN_TIME_CAST_ARG="--cast_to_run_time_type=true"
fi

if [[ $me != *"GRTMinusInputConstruction"* && ($me == *"InputConstruction"* || $me == *"GRT"*) ]]; then
    BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
    INPUT_CONSTRUCTION_ARG="--demand_driven=true"
fi

# InputFuzzing and ConstantMining are not supported at the moment
#if [[ $me == *"InputFuzzing"* ]]; then
#BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
#EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
#INPUT_FUZZING_ARG="--grt_fuzzing=true"
#fi
#
#if [[ $me == *"ConstantMining"* || $me == *"GRT"* ]]; then
#BOOT_CLASS_PATH_ARG="$BOOT_CLASS_PATH_ARG:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
#EXTRA_JAVA_AGENT_ARG="-javaagent:$D4J_DIR_TESTGEN_LIB/jacocoagent.jar"
#CONSTANT_MINING_ARG="--constant-mining=true"
#CONSTANT_MINING_P_CONST_ARG="--constant_mining_probability=0.01"
#fi

# Build the test-generation command
cmd="java \
  -Xbootclasspath/a:$JACOCO_AGENT_JAR:$REPLACECALL_JAR \
  -javaagent:$JACOCO_AGENT_JAR \
  -javaagent:$REPLACECALL_COMMAND \
  -classpath $CLASSPATH*:$SRC_JAR:$GENERATOR_JAR \
  randoop.main.Main gentests \
  $METHOD_SELECTION_ARG \
  $INPUT_SELECTION_ARG \
  $RUN_TIME_CAST_ARG \
  $INPUT_CONSTRUCTION_ARG \
  $INPUT_FUZZING_ARG \
  $CONSTANT_MINING_ARG \
  $CONSTANT_MINING_P_CONST_ARG \
  --testjar=$SRC_JAR \
  --time-limit=$TIME_LIMIT \
  --deterministic=false \
  --no-error-revealing-tests=true \
  --randomseed=0"

# Return this command to the caller
echo "$cmd"
exit 0
