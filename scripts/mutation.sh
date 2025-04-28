#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# This script:
#  * Generates test suites using Randoop.
#  * Computes mutation score (mutants are generated using Major via ant).
#  * Computes code coverage (using Jacoco via Maven).
#
# Directories and files:
# - `build/test*`: Randoop-created test suites.
# - `build/bin`: Compiled tests and code.
# - `results/info.csv`: statistics about each iteration.
# - `results/`: everything else specific to the most recent iteration.


# Fail this script on errors.
set -e
set -o pipefail

USAGE_STRING="usage: mutation.sh <subject-jar> <java-src-dir> <lib-dir>"
if [ $# -eq 0 ]; then
    echo "$0: $USAGE_STRING"
    exit 1
fi

#===============================================================================
# Environment Setup
#===============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAJOR_HOME=$(realpath "${SCRIPT_DIR}/build/major/") # Major home directory, for mutation testing
RANDOOP_JAR=$(realpath "${SCRIPT_DIR}/build/randoop-all-4.3.3.jar") # Randoop jar file
JACOCO_AGENT_JAR=$(realpath "${SCRIPT_DIR}/build/jacocoagent.jar") # For Bloodhound
JACOCO_CLI_JAR=$(realpath "${SCRIPT_DIR}/build/jacococli.jar") # For coverage report generation


#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

NUM_LOOP=1             # Number of experiment runs (10 in GRT paper)
VERBOSE=0              # Verbose option
REDIRECT=0             # Redirect output to mutation_output.txt

SECONDS_PER_CLASS="2"  # Default seconds per class.
                       # The paper runs Randoop with 4 different time limits:
                       # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.

# Name of the subject program.
SUBJECT_PROGRAM="$1"

JAR_DIR="$3"
CLASSPATH="$(echo "$JAR_DIR"/*.jar | tr ' ' ':')"

# Select the ant executable based on the subject program
if [ "$SUBJECT_PROGRAM" = "ClassViewer-5.0.5b" ] || [ "$SUBJECT_PROGRAM" = "jcommander-1.35" ] || [ "$SUBJECT_PROGRAM" = "fixsuite-r48" ]; then
    ANT="ant.m"
    chmod +x "$MAJOR_HOME"/bin/ant.m
else
    ANT="ant"
fi

echo "Running mutation test on $SUBJECT_PROGRAM"
echo

#===============================================================================
# Program Paths & Dependencies
#===============================================================================

# Link to src files for mutation generation and analysis.
JAVA_SRC_DIR="$2"

# Path to the jar file of the subject program.
SRC_JAR=$(realpath "$SCRIPT_DIR/../subject-programs/$SUBJECT_PROGRAM.jar")

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running the test generator.
TIME_LIMIT=$((NUM_CLASSES * SECONDS_PER_CLASS))

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Command line inputs common among all commands.
RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

echo "Using Randoop to generate tests."
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopFeature,FileName,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi


#===============================================================================
# Randoop Feature Selection
#===============================================================================

# The feature names must not contain whitespace.
ALL_RANDOOP_FEATURES=("BASELINE" "BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
# The different features of Randoop to use. Adjust according to the features you are testing.
RANDOOP_FEATURES=("BASELINE") #"BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")

# ABLATION controls whether to perform feature ablation studies.
# If false, each run of Randoop only uses the features specified in the RANDOOP_FEATURES array.
# If true, each run of Randoop uses all features *except* the one specified in the RANDOOP_FEATURES array.
ABLATION=false

# Ensure the given features are are recognized and supported by the script.
for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}" ; do
    if [[ ! " ${ALL_RANDOOP_FEATURES[*]} " =~ [[:space:]]${RANDOOP_FEATURE}[[:space:]] ]]; then
        echo "$RANDOOP_FEATURE" is not in "${RANDOOP_FEATURES[@]}"
        exit 2
    fi
done


#===============================================================================
# Test Generation & Execution
#===============================================================================
# Remove old test directories.
rm -rf "$SCRIPT_DIR"/build/test*

# The value for the -lib command-line option; that is, the classpath.
LIB_ARG="$CLASSPATH"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 "$NUM_LOOP")
do
    for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}"
    do
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)

        FEATURE_NAME=""
        if [[ "$ABLATION" == "true" ]]; then
            FEATURE_NAME="ALL-EXCEPT-$RANDOOP_FEATURE"
        else
            FEATURE_NAME="$RANDOOP_FEATURE"
        fi
        echo "Using $FEATURE_NAME"
        echo

        # Test directory for each iteration.
        TEST_DIRECTORY="$SCRIPT_DIR/build/test/$FEATURE_NAME/$TIMESTAMP"
        mkdir -p "$TEST_DIRECTORY"

        # Result directory for each test generation and execution.
        RESULT_DIR="$SCRIPT_DIR/results/$SUBJECT_PROGRAM-$FEATURE_NAME-$TIMESTAMP"
        mkdir -p "$RESULT_DIR"

        # If the REDIRECT flag is set, redirect all output to a log file.
        if [[ "$REDIRECT" -eq 1 ]]; then
            touch mutation_output.txt
            echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
            exec 3>&1 4>&2
            exec 1>>"mutation_output.txt" 2>&1
        fi

        # Bloodhound
        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "BLOODHOUND" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--method-selection=BLOODHOUND"
        fi

        # Baseline
        if [[ ( "$RANDOOP_FEATURE" == "BASELINE" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "BASELINE" && "$ABLATION" == "true" ) ]]; then
            ## There is nothing to do in this case.
            # FEATURE_FLAG=""
            true
        fi

        # Orienteering
        if [[ ( "$RANDOOP_FEATURE" == "ORIENTEERING" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--input-selection=ORIENTEERING"
        fi

        # Bloodhound and Orienteering
        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--input-selection=ORIENTEERING --method-selection=BLOODHOUND"
        fi

        # Detective (Demand-Driven)
        if [[ ( "$RANDOOP_FEATURE" == "DETECTIVE" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "DETECTIVE" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--demand-driven=true"
        fi

        # GRT Fuzzing
        if [[ ( "$RANDOOP_FEATURE" == "GRT_FUZZING" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "GRT_FUZZING" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--grt-fuzzing=true"
        fi

        # Elephant Brain
        if [[ ( "$RANDOOP_FEATURE" == "ELEPHANT_BRAIN" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "ELEPHANT_BRAIN" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--elephant-brain=true"
        fi

        # Constant Mining
        if [[ ( "$RANDOOP_FEATURE" == "CONSTANT_MINING" && "$ABLATION" != "true" ) \
           || ( "$RANDOOP_FEATURE" != "CONSTANT_MINING" && "$ABLATION" == "true" ) ]]; then
            FEATURE_FLAG="--constant-mining=true"
        fi

        # shellcheck disable=SC2086 # FEATURE_FLAG may contain multiple arguments.
        $RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY $FEATURE_FLAG

        #===============================================================================
        # Coverage & Mutation Analysis
        #===============================================================================

        echo
        echo "Compiling and mutating subject program..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile

        echo
        echo "Compiling tests..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests

        echo
        echo "Running tests with coverage..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" test
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" test

        mv jacoco.exec "$RESULT_DIR"
        java -jar "$JACOCO_CLI_JAR" report "$RESULT_DIR/jacoco.exec" --classfiles "$SRC_JAR" --sourcefiles "$JAVA_SRC_DIR" --csv "$RESULT_DIR"/report.csv

        # Calculate Instruction Coverage
        inst_missed=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' "$RESULT_DIR"/report.csv)
        inst_covered=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' "$RESULT_DIR"/report.csv)
        instruction_coverage=$(echo "scale=4; $inst_covered / ($inst_missed + $inst_covered) * 100" | bc)
        instruction_coverage=$(printf "%.2f" "$instruction_coverage")

        # Calculate Branch Coverage
        branch_missed=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' "$RESULT_DIR"/report.csv)
        branch_covered=$(awk -F, 'NR>1 {sum+=$7} END {print sum}' "$RESULT_DIR"/report.csv)
        branch_coverage=$(echo "scale=4; $branch_covered / ($branch_missed + $branch_covered) * 100" | bc)
        branch_coverage=$(printf "%.2f" "$branch_coverage")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"

        echo
        echo "Running tests with mutation analysis..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test
        fi
        echo
        "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test

        mv results/summary.csv "$RESULT_DIR"

        # Calculate Mutation Score
        mutants_generated=$(awk -F, 'NR==2 {print $3}' "$RESULT_DIR"/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULT_DIR"/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_generated * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"
        echo "Mutation Score: $mutation_score%"

        row="$RANDOOP_FEATURE,$(basename "$SRC_JAR"),$instruction_coverage%,$branch_coverage%,$mutation_score%"
        # info.csv contains a record of each pass.
        echo -e "$row" >> results/info.csv

        # Move output files into the $RESULT_DIR directory.
        FILES_TO_MOVE=(
            "major.log"
            "mutants.log"
            "suppression.log"
            "results/covMap.csv"
            "results/details.csv"
            "results/preprocessing.ser"
            "results/testMap.csv"
        )
        for f in "${FILES_TO_MOVE[@]}"; do
            [ -e "$f" ] && mv "$f" "$RESULT_DIR"
    done
done
