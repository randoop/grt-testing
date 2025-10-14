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
# - `results/$RESULTS_CSV`: statistics about each iteration.
# - `results/`: everything else specific to the most recent iteration.

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
# ./defects4j-evosuite.sh -c 1 -o info.csv -b 1 Lang

#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
USAGE_STRING="usage: defects4j-evosuite.sh -b id -o RESULTS_CSV [-t total_time] [-c time_per_class] [-n num_iterations] [-r] [-v] [-h] PROJECT-ID
  -b id Specify the bug ID of the given project.
        The bug ID uniquely identifies a specific defect instance within the Defects4J project.
        Example: -b 5 (runs the experiment on bug #5 of PROJECT-ID).
  -o N  Write experiment results to this CSV file (N should end in '.csv').
        If the file does not exist, a header row will be created automatically.
        Paths are not allowed; only a filename may be given.
  -t N  Total time limit for test generation (in seconds).
  -c N  Per-class time limit (in seconds, default: 2s/class).
        Mutually exclusive with -t.
  -n N  Number of iterations to run the experiment (default: 1).
  -r    Redirect program logs and diagnostic messages
        to results/result/defects4j_output.txt.
  -v    Enables verbose mode.
  -h    Displays this help message.
  PROJECT-ID is the name of a Project Identifier in Defects4J (e.g., Lang)."

#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `defects4j-prerequisites.md`.

# Fail this script on errors.
set -e
set -o pipefail

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
  echo "Error: $0 requires Java 11, found ${JAVA_VER}"
  exit 2
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
DEFECTS4J_HOME=$(realpath "${SCRIPT_DIR}/build/defects4j/")       # Defects4j home directory
EVOSUITE_JAR=$(realpath "${SCRIPT_DIR}/build/evosuite-1.2.0.jar") # EvoSuite jar file

command -v defects4j >/dev/null 2>&1 || { echo "Error: defects4j not on PATH." >&2; exit 2; }
[ -f "$EVOSUITE_JAR" ] || { echo "Error: Missing $EVOSUITE_JAR." >&2; exit 2; }

. "$SCRIPT_DIR/usejdk.sh" # Source the usejdk.sh script to enable JDK switching
usejdk11

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

NUM_LOOP=1      # Number of experiment runs (10 in GRT paper)
VERBOSE=0       # Verbose option
REDIRECT=0      # Redirect output to defects4j_output.txt
UUID=$(uuidgen) # A unique identifier per instance

# Parse command-line arguments
while getopts ":b:o:t:c:n:rvh" opt; do
  case ${opt} in
    b)
      BUG_ID="$OPTARG"
      ;;
    o)
      RESULTS_CSV="$OPTARG"
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
    r)
      # Redirect output to a log file
      REDIRECT=1
      ;;
    v)
      # Verbose mode
      VERBOSE=1
      ;;
    h)
      # Display help message
      echo "$USAGE_STRING"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "$USAGE_STRING"
      exit 2
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      echo "$USAGE_STRING"
      exit 2
      ;;
  esac
done

shift $((OPTIND - 1))

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

if [[ -z "$RESULTS_CSV" ]]; then
  echo "No -o command-line argument given."
  exit 2
fi

if [[ -z "$BUG_ID" ]]; then
  echo "Error: Bug ID (-b) not specified."
  echo "$USAGE_STRING"
  exit 2
fi

# Name of the project id.
PROJECT_ID="$1"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: PROJECT-ID is required." >&2
  echo "$USAGE_STRING"
  exit 2
fi

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

  # Handle optional redirection of logs/diagnostic messages
  # (if -r is specified, send logs to results/result/defects4j_output.txt)
  if [[ "$REDIRECT" -eq 1 ]]; then
    touch "$RESULT_DIR/defects4j_output.txt"
    echo "Redirecting logs to $RESULT_DIR/defects4j_output.txt..."
    exec 3>&1 4>&2
    exec 1>> "$RESULT_DIR/defects4j_output.txt" 2>&1
  fi

  # Create the experiment results CSV file with a header row if it doesn’t already exist
  {
    exec {fd}>>"$SCRIPT_DIR/results/$RESULTS_CSV"
    flock -n "$fd" || true
    if [ ! -s "$SCRIPT_DIR/results/$RESULTS_CSV" ]; then
      echo "ProjectId,Version,TestSuiteSource,Test,TestClassification,NumTrigger,TimeLimit" >&"$fd"
    fi
    exec {fd}>&-
  }

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

  echo "Appending results to output file $RESULTS_CSV..."
  {
    exec {fd}>>"$SCRIPT_DIR/results/$RESULTS_CSV"
    flock -n "$fd" || true
    tr -d '\r' < "$RESULT_DIR/bug_detection" | tail -n +2 | awk -v time_limit="$TIME_LIMIT" 'NF > 0 {print $0 "," time_limit}' >&"$fd"
    exec {fd}>&-
  }

  if [[ "$REDIRECT" -eq 1 ]]; then
    exec 1>&3 2>&4
    exec 3>&- 4>&-
  fi
done
