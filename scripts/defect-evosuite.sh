#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# This script:
#  * Checks out the fixed version of a program from Defects4J
#  * Generates test suites using EvoSuite on the fixed version
#  * Executes the generated tests on the buggy version to evaluate fault detection
#
# Directories and files:
# - `build/evosuite-tests*`: Generated EvoSuite test suites.
# - `results/$OUTPUT_FILE`: statistics about each iteration.
# - `results/`: everything else specific to the most recent iteration.

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
# ./defect-evosuite.sh -c 1 -o info.csv -b 1 Lang

#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
# See variable USAGE_STRING below

#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `defect-prerequisites.md`.

# Fail this script on errors.
set -e
set -o pipefail

USAGE_STRING="usage: defect-detection-evosuite.sh [-h] [-v] [-r] [-b id] [-o output_file] [-t total_time] [-c time_per_class] [-n num_iterations] PROJECT-ID
  -h    Displays this help message.
  -v    Enables verbose mode.
  -r    Redirect output to results/result/defect_output.txt.
  -b id Specify the bug ID of the given project.
        The bug ID uniquely identifies a specific defect instance within the Defects4J project.
        Example: -b 5 (runs the experiment on bug #5 of PROJECT-ID).
  -o N  Csv output filename; should end in \".csv\"; if relative, should not include a directory name.
  -t N  Total time limit for test generation (in seconds).
  -c N  Per-class time limit (in seconds, default: 2s/class).
        Mutually exclusive with -t.
  -n N  Number of iterations to run the experiment (default: 1).
  PROJECT-ID is the name of a Project Identifier in Defects4J.
  Example: Lang"

if [ $# -eq 0 ]; then
  echo "$0: $USAGE_STRING"
  exit 1
fi

#===============================================================================
# Environment Setup
#===============================================================================

# Requires Java 11
JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{
  if ($1 == "1") {
    print $2
  } else {
    print $1
  }
}')

if [[ "$JAVA_VER" -ne 11 ]]; then
  echo "Error: Java version 11 is required. Please install it and try again."
  exit 1
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
DEFECTS4J_HOME=$(realpath "${SCRIPT_DIR}/build/defects4j/")       # Defects4j home directory
EVOSUITE_JAR=$(realpath "${SCRIPT_DIR}/build/evosuite-1.2.0.jar") # EvoSuite jar file

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

NUM_LOOP=1      # Number of experiment runs (10 in GRT paper)
VERBOSE=0       # Verbose option
REDIRECT=0      # Redirect output to defect_output.txt
UUID=$(uuidgen) # Generate a unique identifier per instance

# Parse command-line arguments
while getopts ":hvro:b:t:c:n:" opt; do
  case ${opt} in
    h)
      # Display help message
      echo "$USAGE_STRING"
      exit 0
      ;;
    v)
      # Verbose mode
      VERBOSE=1
      ;;
    r)
      # Redirect output to a log file
      REDIRECT=1
      ;;
    o)
      OUTPUT_FILE="$OPTARG"
      ;;
    b)
      BUG_ID="$OPTARG"
      ;;
    t)
      # Total experiment time
      TOTAL_TIME="$OPTARG"
      ;;
    c)
      # seconds per class
      SECONDS_PER_CLASS="$OPTARG"
      ;;
    n)
      # Number of iterations to run the experiment
      NUM_LOOP="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "$USAGE_STRING"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      echo "$USAGE_STRING"
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ -z "$OUTPUT_FILE" ]]; then
  echo "No -o command-line argument given."
  exit 2
fi

# Enforce that mutually exclusive options are not bundled together
if [[ -n "$TOTAL_TIME" ]] && [[ -n "$SECONDS_PER_CLASS" ]]; then
  echo "Options -t and -c cannot be used together in any form (e.g., -t -c)."
  exit 2
fi

# Default to 2 seconds per class if not specified
if [[ -z "$SECONDS_PER_CLASS" ]] && [[ -z "$TOTAL_TIME" ]]; then
  echo "Defaulting to 2 seconds per class..."
  SECONDS_PER_CLASS=2
fi

if [[ -z "$BUG_ID" ]]; then
  echo "Error: Bug ID (-b) not specified."
  echo "$USAGE_STRING"
  exit 1
fi

# Name of the project id.
PROJECT_ID="$1"

echo "Running defect detection on $PROJECT_ID for bug $BUG_ID with EvoSuite..."
echo

#===============================================================================
# Directory Setup
#===============================================================================

FILE_SUFFIX="$PROJECT_ID-EVOSUITE-$UUID"

FIXED_WORK_DIR="$SCRIPT_DIR/build/defects4j-src/$PROJECT_ID-${BUG_ID}f/$FILE_SUFFIX"
TEST_DIR="$SCRIPT_DIR/build/evosuite-tests/$FILE_SUFFIX"
REPORT_DIR="$SCRIPT_DIR/build/evosuite-report/$FILE_SUFFIX"
RELEVANT_CLASSES_FILE="$TEST_DIR/relevant_classes.txt"
RESULT_DIR="$SCRIPT_DIR/results/$FILE_SUFFIX"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used
for i in $(seq 1 "$NUM_LOOP"); do

  # Clean up and create necessary directories
  rm -rf "$FIXED_WORK_DIR" "$TEST_DIR" "$REPORT_DIR" "$RESULT_DIR"
  mkdir -p "$FIXED_WORK_DIR" "$TEST_DIR" "$REPORT_DIR" "$RESULT_DIR"
  touch "$RELEVANT_CLASSES_FILE"

  # Handle optional output redirection
  if [[ "$REDIRECT" -eq 1 ]]; then
    touch "$RESULT_DIR/defect_output.txt"
    echo "Redirecting output to $RESULT_DIR/defect_output.txt..."
    exec 3>&1 4>&2
    exec 1>> "$RESULT_DIR/defect_output.txt" 2>&1
  fi

  # Create output file with header if it doesn't exist
  if [ ! -f "$SCRIPT_DIR/results/$OUTPUT_FILE" ]; then
    echo -e "ProjectId,Version,TestSuiteSource,Test,TestClassification,NumTrigger,TimeLimit" > "$SCRIPT_DIR/results/$OUTPUT_FILE"
  fi

  #===============================================================================
  # Checkout and Setup Defects4J Project
  #===============================================================================

  echo "Checking out fixed version ${BUG_ID}f of $PROJECT_ID..."
  defects4j checkout -p "$PROJECT_ID" -v "${BUG_ID}f" -w "$FIXED_WORK_DIR"

  PROJECT_CP=$(defects4j export -p cp.compile -w "$FIXED_WORK_DIR")

  # Export fault-relevant classes
  defects4j export -p classes.relevant -w "$FIXED_WORK_DIR" > "$RELEVANT_CLASSES_FILE"

  #===============================================================================
  # Time Budget Allocation
  #===============================================================================

  # Count the number of relevant classes
  NUM_CLASSES=$(wc -l < "$RELEVANT_CLASSES_FILE")

  if [ "$NUM_CLASSES" -le 0 ]; then
    echo "No relevant classes found."
    exit 1
  fi

  if [[ -n "$SECONDS_PER_CLASS" ]]; then
    TIME_LIMIT="$SECONDS_PER_CLASS"
  else
    TIME_LIMIT=$((TOTAL_TIME / NUM_CLASSES))
    if [ "$TIME_LIMIT" -lt 1 ]; then
      TIME_LIMIT=1
    fi
  fi

  #===============================================================================
  # Test Generation
  #===============================================================================

  echo "Generating tests with EvoSuite..."
  while IFS= read -r CLASS; do
    EVOSUITE_BASE_COMMAND="java \
    -jar $EVOSUITE_JAR \
    -class $CLASS \
    -projectCP $PROJECT_CP \
    -seed 0 \
    -Dsearch_budget=$TIME_LIMIT \
    -Dassertion_timeout=$TIME_LIMIT \
    -Dtest_dir=$TEST_DIR \
    -Dreport_dir=$REPORT_DIR"

    if [ "$VERBOSE" -eq 1 ]; then
      echo "EvoSuite command:"
      echo "$EVOSUITE_BASE_COMMAND"
      echo
    fi

    cd "$RESULT_DIR"
    $EVOSUITE_BASE_COMMAND
  done < "$RELEVANT_CLASSES_FILE"

  # Clean up files
  rm "$RELEVANT_CLASSES_FILE"

  #===============================================================================
  # Run Bug Detection
  #===============================================================================

  # run_bug_detection.pl expects a tar.bz2 file of the tests
  (
    cd "$TEST_DIR" \
      && tar -cjf "${PROJECT_ID}-${BUG_ID}f-evosuite.tar.bz2" . \
      || {
        rc=$?
        if [ $rc -eq 1 ]; then echo "Warning ignored: tar returned code 1"; else exit $rc; fi
      } \
      && find . -name '*.java' -delete
  )

  echo "Running bug detection with defects4j..."
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$DEFECTS4J_HOME/framework/bin/run_bug_detection.pl -p $PROJECT_ID -d $TEST_DIR -o $RESULT_DIR"
    echo
  fi

  "$DEFECTS4J_HOME"/framework/bin/run_bug_detection.pl -p "$PROJECT_ID" -d "$TEST_DIR" -o "$RESULT_DIR"

  #===============================================================================
  # Append Detection Results and Clean Up
  #===============================================================================

  echo "Appending results to output file $OUTPUT_FILE..."
  tr -d '\r' < "$RESULT_DIR/bug_detection" | tail -n +2 | awk -v time_limit="$TIME_LIMIT" 'NF > 0 {print $0 "," time_limit}' >> "$SCRIPT_DIR/results/$OUTPUT_FILE"

  if [[ "$REDIRECT" -eq 1 ]]; then
    exec 1>&3 2>&4
    exec 3>&- 4>&-
  fi
done
