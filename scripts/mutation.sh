#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# For documentation of how to run this script, see file `mutation-repro.md`.
#
# This script:
#  * uses Randoop to generate test suites for subject programs and
#  * performs mutation testing to determine how Randoop features affect
#    various coverage metrics including coverage and mutation score
#    (mutants are generated using Major).
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

. ${SCRIPT_DIR}/usejdk.sh


#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================
SECONDS_PER_CLASS="2"  # Default seconds per class.
                       # The paper runs Randoop with 4 different time limits:
                       # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.

NUM_LOOP=1             # Number of experiment runs (10 in GRT paper)

#===============================================================================
# Project Paths & Dependencies
#===============================================================================
# Link to src jar.
SRC_JAR=$(realpath "$SCRIPT_DIR/../subject-programs/$1")

# Link to src files for mutation generation and analysis.
JAVA_SRC_DIR="$2"

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop.
TIME_LIMIT=$((NUM_CLASSES * SECONDS_PER_CLASS))

# Command line inputs common among all commands.
RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

echo "Using Randoop to generate tests"
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopFeature,FileName,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

JAR_DIR="$3"
CLASSPATH="$(echo "$JAR_DIR"/*.jar | tr ' ' ':')"


#===============================================================================
# Randoop Feature Selection
#===============================================================================

# The feature names must not contain whitespace.
ALL_RANDOOP_FEATURES=("BASELINE" "BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
# The different features of Randoop to use. Adjust according to the features you are testing.
RANDOOP_FEATURES=("BASELINE") #"BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")

# ABLATION controls whether to perform feature ablation studies.
# If false, Randoop only uses the features specified in the RANDOOP_FEATURES array.
# If true, each run uses all Randoop features *except* the one specified in the RANDOOP_FEATURES array.
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

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}"
    do
        FEATURE_NAME=""
        if [[ "$ABLATION" == "true" ]]; then
            FEATURE_NAME="ALL-EXCEPT-$RANDOOP_FEATURE"
        else
            FEATURE_NAME="$RANDOOP_FEATURE"
        fi

        echo "Using $FEATURE_NAME"
        echo

        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        # Test directory for each iteration.
        TEST_DIRECTORY="$SCRIPT_DIR/build/test/$FEATURE_NAME/$TIMESTAMP"
        mkdir -p "$TEST_DIRECTORY"

        # Result directory for each test generation and execution.
        RESULTS_DIR="$SCRIPT_DIR/results/$1-$FEATURE_NAME-$TIMESTAMP"
        mkdir -p "$RESULTS_DIR"

        RANDOOP_COMMAND_2="$RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY"

        # Bloodhound
        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BLOODHOUND" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --method-selection=BLOODHOUND"
        fi

        # Baseline
        if [[ ( "$RANDOOP_FEATURE" == "BASELINE" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BASELINE" && "$ABLATION" == "true" ) ]]; then
            ## There is nothing to do in this case.
            # RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2"
            true
        fi

        # Orienteering
        if [[ ( "$RANDOOP_FEATURE" == "ORIENTEERING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --input-selection=ORIENTEERING"
        fi

        # Bloodhound and Orienteering
        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --input-selection=ORIENTEERING --method-selection=BLOODHOUND"
        fi

        # Detective (Demand-Driven)
        if [[ ( "$RANDOOP_FEATURE" == "DETECTIVE" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "DETECTIVE" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --demand-driven=true"
        fi

        # GRT Fuzzing
        if [[ ( "$RANDOOP_FEATURE" == "GRT_FUZZING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "GRT_FUZZING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --grt-fuzzing=true"
        fi

        # Elephant Brain
        if [[ ( "$RANDOOP_FEATURE" == "ELEPHANT_BRAIN" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "ELEPHANT_BRAIN" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --elephant-brain=true"
        fi

        # Constant Mining
        if [[ ( "$RANDOOP_FEATURE" == "CONSTANT_MINING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "CONSTANT_MINING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --constant-mining=true"
        fi

        usejdk11 # Randoop requires Java 11
        $RANDOOP_COMMAND_2
        usejdk8 # Subject programs require Java 8

        #===============================================================================
        # Coverage & Mutation Analysis
        #===============================================================================

        echo
        echo "Compiling and mutating project..."
        echo "($MAJOR_HOME/bin/ant -Dmutator=\"mml:$MAJOR_HOME/mml/all.mml.bin\" -Dsrc=\"$JAVA_SRC_DIR\" -lib \"$CLASSPATH\" clean compile)"
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile

        echo
        echo "Compiling tests..."
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" compile.tests

        echo
        echo "Running tests with coverage..."
        echo "($MAJOR_HOME/bin/ant -Dmutator=\"mml:$MAJOR_HOME/mml/all.mml.bin\" -Dtest=\"$TEST_DIRECTORY\" -Dsrc=\"$JAVA_SRC_DIR\" -lib \"$CLASSPATH\" test)"
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" test

        mv jacoco.exec "$RESULTS_DIR"
        java -jar "$JACOCO_CLI_JAR" report "$RESULTS_DIR/jacoco.exec" --classfiles "$SRC_JAR" --sourcefiles "$JAVA_SRC_DIR" --csv "$RESULTS_DIR"/report.csv

        # Calculate Instruction Coverage
        inst_missed=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' "$RESULTS_DIR"/report.csv)
        inst_covered=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' "$RESULTS_DIR"/report.csv)
        instruction_coverage=$(echo "scale=4; $inst_covered / ($inst_missed + $inst_covered) * 100" | bc)
        instruction_coverage=$(printf "%.2f" "$instruction_coverage")

        # Calculate Branch Coverage
        branch_missed=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' "$RESULTS_DIR"/report.csv)
        branch_covered=$(awk -F, 'NR>1 {sum+=$7} END {print sum}' "$RESULTS_DIR"/report.csv)
        branch_coverage=$(echo "scale=4; $branch_covered / ($branch_missed + $branch_covered) * 100" | bc)
        branch_coverage=$(printf "%.2f" "$branch_coverage")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"

        echo
        echo "Running tests with mutation analysis..."
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -lib "$CLASSPATH" mutation.test

        mv results/summary.csv "$RESULTS_DIR"

        # Calculate Mutation Score
        mutants_covered=$(awk -F, 'NR==2 {print $3}' "$RESULTS_DIR"/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULTS_DIR"/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Mutation Score: $mutation_score%"

        row="$RANDOOP_FEATURE,$(basename "$SRC_JAR"),$instruction_coverage%,$branch_coverage%,$mutation_score%"
        # info.csv contains a record of each pass.
        echo -e "$row" >> results/info.csv

        # Move output files into the $RESULTS_DIR directory.
        FILES_TO_MOVE=(
            "suppression.log"
            "major.log"
            "mutants.log"
            "results/covMap.csv"
            "results/details.csv"
            "results/preprocessing.ser"
            "results/testMap.csv"
        )
        mv "${FILES_TO_MOVE[@]}" "$RESULTS_DIR"
    done
done
