#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# This script:
#  * uses Randoop to generate test suites for a subject program and
#  * performs mutation testing to determine how Randoop features affect
#    various coverage metrics including coverage and mutation score
#    (mutants are generated using Major).

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
#   ./mutation.sh -c 1 commons-lang3-3.0

#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
# See variable USAGE_STRING below

#------------------------------------------------------------------------------
# Outputs:
#------------------------------------------------------------------------------
# - build/test*   : Randoop-created test suites.
# - build/bin     : Compiled tests and subject code.
# - results/      : All output from the current run.
# - results/info.csv : Summary of statistics (coverage, mutation score, etc.).

#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.

#------------------------------------------------------------------------------
# Randoop versions (for GRT features):
#------------------------------------------------------------------------------
# For Demand-driven (PR #1260), GRT Fuzzing (PR #1304), and Elephant Brain (PR #1347),
# checkout the respective pull requests from the Randoop repository and build locally.

# Fail this script on errors.
set -e
set -o pipefail

USAGE_STRING="usage: mutation.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] [-n num_iterations] TEST-CASE-NAME
  -h    Displays this help message.
  -v    Enables verbose mode.
  -r    Redirect Randoop and Major output to results/result/mutation_output.txt.
  -t N  Total time limit for Randoop test generation (in seconds).
  -c N  Per-class time limit for Randoop (in seconds, default: 2s/class).
        Mutually exclusive with -t.
  -n N  Number of iterations to run the experiment (default: 1).
  TEST-CASE-NAME is the name of a jar file in ../subject-programs/, without .jar.
  Example: commons-lang3-3.0"

if [ $# -eq 0 ]; then
    echo "$0: $USAGE_STRING"
    exit 1
fi

#===============================================================================
# Environment Setup
#===============================================================================

# Requires Java 8
JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{sub("^$", "0", $2); print $1$2}')
if [[ "$JAVA_VER" -ne 18 ]]; then
    echo "Error: Java version 8 is required. Please install it and try again."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAJOR_HOME=$(realpath "${SCRIPT_DIR}/build/major/") # Major home directory, for mutation testing
RANDOOP_JAR=$(realpath "${SCRIPT_DIR}/build/randoop-all-4.3.3.jar") # Randoop jar file
JACOCO_AGENT_JAR=$(realpath "${SCRIPT_DIR}/build/jacocoagent.jar") # For Bloodhound
JACOCO_CLI_JAR=$(realpath "${SCRIPT_DIR}/build/jacococli.jar") # For coverage report generation
REPLACECALL_JAR=$(realpath "build/replacecall-4.3.3.jar") # For replacing undesired method calls


#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

NUM_LOOP=1             # Number of experiment runs (10 in GRT paper)
VERBOSE=0              # Verbose option
REDIRECT=0             # Redirect output to mutation_output.txt

# Parse command-line arguments
while getopts ":hvrt:c:n:" opt; do
  case ${opt} in
    h )
      # Display help message
      echo "$USAGE_STRING"
      exit 0
      ;;
    v )
      # Verbose mode
      VERBOSE=1
      ;;
    r )
      # Redirect output to a log file
      REDIRECT=1
      ;;
    t )
      # Total experiment time, mutually exclusive with SECONDS_PER_CLASS
      TOTAL_TIME="$OPTARG"
      ;;
    c )
      # Default seconds per class.
      # The paper runs Randoop with 4 different time limits:
      # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.
      SECONDS_PER_CLASS="$OPTARG"
      ;;
    n )
      # Number of iterations to run the experiment
      NUM_LOOP="$OPTARG"
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

# Enforce that mutually exclusive options are not bundled together
if [[ -n "$TOTAL_TIME" ]] && [[ -n "$SECONDS_PER_CLASS" ]]; then
  echo "Options -t and -c cannot be used together in any form (e.g., -t -c)."
  exit 1
fi

# Default to 2 seconds per class if not specified
if [[ -z "$SECONDS_PER_CLASS" ]] && [[ -z "$TOTAL_TIME" ]]; then
    SECONDS_PER_CLASS=2
fi

# Name of the subject program
SUBJECT_PROGRAM="$1"

# Select the ant executable based on the subject program
if [ "$SUBJECT_PROGRAM" = "ClassViewer-5.0.5b" ] || [ "$SUBJECT_PROGRAM" = "jcommander-1.35" ] || [ "$SUBJECT_PROGRAM" = "fixsuite-r48" ]; then
    ANT="ant-replacecall"
    chmod +x "$MAJOR_HOME"/bin/ant-replacecall
else
    ANT="ant"
fi

echo "Running mutation test on $1"
echo

#===============================================================================
# Program Paths & Dependencies
#===============================================================================

# Path to the base directory of the source code.
SRC_BASE_DIR="$(realpath "$SCRIPT_DIR/../subject-programs/src/$SUBJECT_PROGRAM")"

# Path to the jar file of the subject program.
SRC_JAR=$(realpath "$SCRIPT_DIR/../subject-programs/$SUBJECT_PROGRAM.jar")

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop.
if [[ -n "$TOTAL_TIME" ]]; then
    TIME_LIMIT="$TOTAL_TIME"
else
    TIME_LIMIT=$((NUM_CLASSES * SECONDS_PER_CLASS))
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Map subject programs to their source directories.
# Subject programs not listed here default to top-level source directory ($SRC_BASE_DIR).
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
JAVA_SRC_DIR=$SRC_BASE_DIR${program_src[$SUBJECT_PROGRAM]}

# Map subject programs to their dependencies
declare -A program_deps=(
    ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
    ["fixsuite-r48"]="$SRC_BASE_DIR/lib/"
    ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
    ["JSAP-2.1"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"  # need to override ant.jar in $SRC_BASE_DIR/lib
    ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
    ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
    ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

CLASSPATH=${program_deps[$SUBJECT_PROGRAM]}

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
# Randoop Command Configuration
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
./apply-build-patch.sh "$SUBJECT_PROGRAM"

cd "$JAVA_SRC_DIR" || exit 1
if git checkout include-major >/dev/null 2>&1; then
    echo "Checked out include-major."
fi
cd - || exit 1

echo "Using Randoop to generate tests"
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopVersion,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
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
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile

        echo
        echo "Compiling tests..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" $LIB_ARG compile.tests
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" $LIB_ARG compile.tests

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
            echo "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" $LIB_ARG mutation.test
        fi
        echo
        "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" $LIB_ARG mutation.test

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
            "suppression.log"
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
# restore build.xml
./apply-build-patch.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd "$JAVA_SRC_DIR"; git checkout main 1>/dev/null)
