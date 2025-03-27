#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# For documentation of how to run this script, see file `mutation-repro.md`.
#
# This script:
#  * Generates test suites using Randoop.
#  * Computes mutation score (mutants are generated using Major via ant).
#  * Computes code coverage (using Jacoco via Maven).
# The metrics can be used to determine how Randoop features affect performance.
#
#
# Directories and files:
# - `build/test*`: generated test suites, including their compiled versions.
# - `build/bin`: Compiled tests and code.
# - `results/info.csv`: statistics about each iteration.
# - `results/`: everything else specific to the most recent iteration.

# Fail this script on errors.
set -e
set -o pipefail

USAGE_STRING="usage: mutation.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
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
REPLACECALL_JAR=$(realpath "build/replacecall-4.3.3.jar") # For replacing undesired method calls

. "${SCRIPT_DIR}/usejdk.sh"


#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================
SECONDS_CLASS="2"      # Default seconds per class.
                       # The paper runs the test generator with 4 different time limits:
                       # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.

TOTAL_TIME=""          # Total experiment time, mutually exclusive with SECONDS_CLASS
SECONDS_CLASS=""       # Seconds per class, mutually exclusive with TOTAL_TIME
NUM_LOOP=1             # Number of experiment runs (10 in GRT paper)
VERBOSE=0              # Verbose option
REDIRECT=0             # Redirect output to mutation_output.txt


# Check for invalid combinations of command-line arguments
for arg in "$@"; do
  if [[ "$arg" =~ ^-[^-].* ]]; then
    if [[ "$arg" =~ t ]] && [[ "$arg" =~ c ]]; then
      echo "Options -t and -c cannot be used together in any form (e.g., -tc or -ct)."
      exit 1
    fi
  fi
done

# Parse command-line arguments
while getopts ":hvrt:c:" opt; do
  case ${opt} in
    h )
      # Display help message
      echo "$USAGE_STRING"
      exit 0
      ;;
    v )
      VERBOSE=1
      ;;
    r )
      REDIRECT=1
      ;;
    t )
      # If -c has already been set, error out.
      if [ -n "$SECONDS_CLASS" ]; then
        echo "Options -t and -c cannot be used together in any form (e.g., -t a -c b)."
        exit 1
      fi
      TOTAL_TIME="$OPTARG"
      ;;
    c )
      # If -t has already been set, error out.
      if [ -n "$TOTAL_TIME" ]; then
        echo "Options -t and -c cannot be used together in any form (e.g., -c a -t b)."
        exit 1
      fi
      SECONDS_CLASS="$OPTARG"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      echo "$USAGE_STRING"
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      echo "$USAGE_STRING"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

# Name of the subject program.
SUBJECT_PROGRAM="$1"

# Select the ant executable based on the subject program
if [ "$SUBJECT_PROGRAM" = "ClassViewer-5.0.5b" ] || [ "$SUBJECT_PROGRAM" = "jcommander-1.35" ] || [ "$SUBJECT_PROGRAM" = "fixsuite-r48" ]; then
    ANT="ant.m"
    chmod +x "$MAJOR_HOME"/bin/ant.m
else
    ANT="ant"
fi

echo "Running mutation test on $1"
echo

#===============================================================================
# Project Paths & Dependencies
#===============================================================================

# Path to the base directory of the source code.
SRC_BASE_DIR="$(realpath "$SCRIPT_DIR/../subject-programs/src/$SUBJECT_PROGRAM")"

# Path to the jar file of the subject program.
SRC_JAR=$(realpath "$SCRIPT_DIR/../subject-programs/$SUBJECT_PROGRAM.jar")

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running the test generator.
if [[ -n "$TOTAL_TIME" ]]; then
    TIME_LIMIT="$TOTAL_TIME"
else
    TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Map subject programs to their source directories
declare -A program_src=(
    ["a4j-1.0b"]="/src/"
    ["asm-5.0.1"]="/src/"
    ["bcel-5.2"]="/src/"
    ["commons-codec-1.9"]="/src/main/java/"
    ["commons-collections4-4.0"]="/src/main/java/"
    ["commons-lang3-3.0"]="/src/main/java/"
    ["commons-math3-3.2"]="/src/main/java/"
    ["commons-primitives-1.0"]="/src/java/"
    ["dcParseArgs-10.2008"]="/src/"
    ["javassist-3.19"]="/src/main/"
    ["jdom-1.0"]="/src/"
    ["JSAP-2.1"]="/src/"
    ["nekomud-r16"]="/src/"
    ["shiro-core-1.2.3"]="/core/"
    ["slf4j-api-1.7.12"]="/slf4j-api"
)
# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$SRC_BASE_DIR${program_src[$SUBJECT_PROGRAM]}

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
    ["fixsuite-r48"]="$SRC_BASE_DIR/lib/"
    ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
    ["JSAP-2.1"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"  # need to override ant.jar in $SRC_BASE_DIR/lib
    ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
    ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
    ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

# Link to dependencies
CLASSPATH=${project_deps[$SUBJECT_PROGRAM]}

LIB_ARG=""
if [[ $CLASSPATH ]]; then
    LIB_ARG="-lib $CLASSPATH"
fi

if [[ "$VERBOSE" -eq 1 ]]; then
    echo "JAVA_SRC_DIR: $JAVA_SRC_DIR"
    echo "CLASSPATH: $CLASSPATH"
    echo
fi


#===============================================================================
# Method Call Replacement Setup
#===============================================================================
# Path to the replacement file for replacecall
REPLACEMENT_FILE_PATH="program-config/$SUBJECT_PROGRAM/replacecall-replacements.txt"

# Configure method call replacements to avoid undesired behaviors during test
# generation.
# Map subject programs to their respective replacement files.
declare -A replacement_files=(
     # Do not wait for user input
     ["jcommander-1.35"]="=--replacement_file=$REPLACEMENT_FILE_PATH"
)
REPLACECALL_COMMAND="$REPLACECALL_JAR${replacement_files[$SUBJECT_PROGRAM]}"


#===============================================================================
# Test generator command configuration
#===============================================================================
RANDOOP_BASE_COMMAND="java \
-Xbootclasspath/a:$JACOCO_AGENT_JAR:$REPLACECALL_JAR \
-javaagent:$JACOCO_AGENT_JAR \
-javaagent:$REPLACECALL_COMMAND \
-classpath $CLASSPATH*:$SRC_JAR:$RANDOOP_JAR \
randoop.main.Main gentests \
--testjar=$SRC_JAR \
--time-limit=$TIME_LIMIT \
--deterministic=false \
--no-error-revealing-tests=true \
--randomseed=0"

# Add special command suffixes for specific subject programs
declare -A command_suffix=(
    # Specify valid inputs to prevent infinite loops during test generation/execution
    ["ClassViewer-5.0.5b"]="--specifications=program-specs/ClassViewer-5.0.5b-specs.json"
    ["commons-cli-1.2"]="--specifications=program-specs/commons-cli-1.2-specs.json"
    ["commons-lang3-3.0"]="--specifications=program-specs/commons-lang3-3.0-specs.json"
    ["fixsuite-r48"]="--specifications=program-specs/fixsuite-r48-specs.json"
    ["guava-16.0.1"]="--specifications=program-specs/guava-16.0.1-specs.json"
    ["jaxen-1.1.6"]="--specifications=program-specs/jaxen-1.1.6-specs.json"
    ["sat4j-core-2.3.5"]="--specifications=program-specs/sat4j-core-2.3.5-specs.json"

    # Randoop generates bad sequences for handling webserver lifecycle, don't test them
    ["javassist-3.19"]="--omit-methods=^javassist\.tools\.web\.Webserver\.run\(\)$ --omit-methods=^javassist\.tools\.rmi\.AppletServer\.run\(\)$"
    # PrintStream.close() is called to close System.out during Randoop test generation.
    # This will interrupt the test generation process. Omit the close() method.
    ["javax.mail-1.5.1"]="--omit-methods=^java\.io\.PrintStream\.close\(\)$|^java\.io\.FilterOutputStream\.close\(\)$|^java\.io\.OutputStream\.close\(\)$|^com\.sun\.mail\.util\.BASE64EncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QPEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.UUEncoderStream\.close\(\)$"
    # JDOMAbout cannot be found during test.compile.
    ["jdom-1.0"]="--omit-classes=^JDOMAbout$"

    # Long execution time due to excessive computation for some inputs.
    # Specify input range to reduce computation and test execution time.
    ["commons-collections4-4.0"]="--specifications=program-specs/commons-collections4-4.0-specs.json"
    # Force termination if a test case takes too long to execute
    ["commons-math3-3.2"]="--usethreads=true"
)

RANDOOP_COMMAND="$RANDOOP_BASE_COMMAND ${command_suffix[$SUBJECT_PROGRAM]}"


#===============================================================================
# Build System Preparation
#===============================================================================

echo "Modifying build.xml for $SUBJECT_PROGRAM..."
./apply-build-patch-randoop.sh "$SUBJECT_PROGRAM"

cd "$JAVA_SRC_DIR" || exit 1
if git checkout include-major >/dev/null 2>&1; then
    echo "Checked out include-major."
fi
cd - || exit 1

echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "Version,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi


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
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        # Test directory for each iteration.
        TEST_DIRECTORY="$SCRIPT_DIR/build/test/$FEATURE_NAME/$TIMESTAMP"
        mkdir -p "$TEST_DIRECTORY"

        # Result directory for each test generation and execution.
        RESULT_DIR="$SCRIPT_DIR/results/$1-$FEATURE_NAME-$TIMESTAMP"
        mkdir -p "$RESULT_DIR"

        # Check if output needs to be redirected for this loop.
        # If the REDIRECT flag is set, redirect all output to a log file for this iteration.
        if [[ "$REDIRECT" -eq 1 ]]; then
            touch mutation_output.txt
            echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
            exec 3>&1 4>&2
            exec 1>>"mutation_output.txt" 2>&1
        fi

        FEATURE_NAME=""
        if [[ "$ABLATION" == "true" ]]; then
            FEATURE_NAME="ALL-EXCEPT-RANDOOP-$RANDOOP_FEATURE"
        else
            FEATURE_NAME="RANDOOP-$RANDOOP_FEATURE"
        fi

        echo "Using $FEATURE_NAME"
        echo

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
        echo "Compiling and mutating subject program..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile

        echo
        echo "Compiling tests..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests

        echo
        echo "Running tests with coverage..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" test
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" test

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
            echo "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test
        fi
        echo
        "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test

        mv results/summary.csv "$RESULT_DIR"

        # Calculate Mutation Score
        mutants_covered=$(awk -F, 'NR==2 {print $3}' "$RESULT_DIR"/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULT_DIR"/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"
        echo "Mutation Score: $mutation_score%"

        row="$FEATURE_NAME,$(basename "$SRC_JAR"),$TIME_LIMIT,0,$instruction_coverage%,$branch_coverage%,$mutation_score%"
        # info.csv contains a record of each pass.
        echo -e "$row" >> results/info.csv

        # Copy the test suites to results directory
        echo "Copying test suites to results directory..."
        cp -r "$TEST_DIRECTORY" "$RESULT_DIR"

        if [[ "$REDIRECT" -eq 1 ]]; then
            echo "Move mutation_output to results directory..."
            mv mutation_output.txt "$RESULT_DIR"
            exec 1>&3 2>&4
            exec 3>&- 4>&-
        fi

        # Move output files into the $RESULT_DIR directory.
        FILES_TO_MOVE=(
            "major.log"
            "mutants.log"
            "results/covMap.csv"
            "results/details.csv"
            "results/preprocessing.ser"
            "results/testMap.csv"
        )
        mv "${FILES_TO_MOVE[@]}" "$RESULT_DIR"
    done
done


#===============================================================================
# Build System Cleanup
#===============================================================================

echo

echo "Restoring build.xml"
./apply-build-patch-randoop.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd "$JAVA_SRC_DIR"; git checkout main 1>/dev/null)
