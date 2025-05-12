#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# This script uses the specified generator to:
#  * generate test suites for subject programs and
#  * performs mutation testing to determine how generator features affect
#    various coverage metrics including coverage and mutation score
#    (mutants are generated using Major).
#
# Each experiment can run multiple times, with a configurable time (in
# seconds per class or total time).
#
# Directories and files:
# - `build/test*`: Randoop-created test suites.
# - `build/bin`: Compiled tests and code.
# - `results/info.csv`: statistics about each iteration.
# - 'results/`: everything else specific to the most recent iteration.

# Fail this script on errors.
set -e
set -o pipefail

# Check for Java 8
JAVA_VERSION=$(java -version 2>&1 | awk -F'[._"]' 'NR==1{print ($2 == "version" && $3 < 9) ? $4 : $3}')
if [ "$JAVA_VERSION" -ne 8 ]; then
  echo "Requires Java 8. Please use Java 8 to proceed."
  exit 1
fi

USAGE_STRING="usage: mutation-fig6-unit.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"

if [ $# -eq 0 ]; then
  echo "$0: $USAGE_STRING"
  exit 1
fi

usejdk8() {
  export JAVA_HOME=~/java/jdk8u292-b10
  export PATH=$JAVA_HOME/bin:$PATH
}
usejdk11() {
  export JAVA_HOME=~/java/jdk-11.0.9.1+1
  export PATH=$JAVA_HOME/bin:$PATH
}

#===============================================================================
# Environment Setup
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
GENERATOR_DIR="$SCRIPT_DIR/generators"
MAJOR_HOME=$(realpath "build/major/") # Major home directory, for mutation testing
CURR_DIR=$(realpath "$(pwd)")
EVOSUITE_JAR=$(realpath "build/evosuite-1.1.0.jar")       # Evosuite jar file
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")     # Randoop jar file
JACOCO_AGENT_JAR=$(realpath "build/jacocoagent.jar")      # For Bloodhound
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")          # For coverage report generation
REPLACECALL_JAR=$(realpath "build/replacecall-4.3.3.jar") # For replacing undesired method calls

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================
SECONDS_CLASS="2" # Default seconds per class.
# The paper runs Randoop with 4 different time limits:
# 2 s/class, 10 s/class, 30 s/class, and 60 s/class.

TOTAL_TIME="" # Total experiment time, mutually exclusive with SECONDS_CLASS
NUM_LOOP=1    # Number of experiment runs (10 in GRT paper)
VERBOSE=0     # Verbose option
REDIRECT=0    # Redirect output to mutation_output.txt

# Check for invalid combinations of command-line arguments
for arg in "$@"; do
  if [[ "$arg" =~ ^-[^-].* ]]; then
    if [[ "$arg" =~ t ]] && [[ "$arg" =~ c ]]; then
      echo "Options -t and -c cannot be used together in any form (e.g., -tc or -ct)."
      exit 1
    fi
  fi
done

# Initialize variables
TOTAL_TIME=""
SECONDS_CLASS=""
GENERATOR=""

# Parse command-line arguments
while getopts ":hvrt:c:g:" opt; do
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
    t)
      # If -c has already been set, error out.
      if [ -n "$SECONDS_CLASS" ]; then
        echo "Options -t and -c cannot be used together in any form (e.g., -t a -c b)."
        exit 1
      fi
      TOTAL_TIME="$OPTARG"
      ;;
    c)
      # If -t has already been set, error out.
      if [ -n "$TOTAL_TIME" ]; then
        echo "Options -t and -c cannot be used together in any form (e.g., -c a -t b)."
        exit 1
      fi
      SECONDS_CLASS="$OPTARG"
      ;;
    g)
      if [[ ! -f "$GENERATOR_DIR/$OPTARG.sh" ]]; then
        echo "Invalid generator. See $GENERATOR_DIR/*.sh for valid generators"
        exit 1
      fi
      GENERATOR="$OPTARG"
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

# Name of the subject program
SUBJECT_PROGRAM="$1"

# Select the ant executable based on the subject program
if [ "$SUBJECT_PROGRAM" = "ClassViewer-5.0.5b" ] || [ "$SUBJECT_PROGRAM" = "jcommander-1.35" ] || [ "$SUBJECT_PROGRAM" = "fixsuite-r48" ]; then
  ANT="ant.m"
  chmod +x "$MAJOR_HOME"/bin/ant.m
else
  ANT="ant"
fi

echo "Running mutation test on $1 on generator $GENERATOR"
echo

#===============================================================================
# Project Paths & Dependencies
#===============================================================================

# Path to the base directory of the source code
SRC_BASE_DIR="$(realpath "$SCRIPT_DIR/../subject-programs/src/$SUBJECT_PROGRAM")"

# Path to the jar file of the subject program
SRC_JAR=$(realpath "$SCRIPT_DIR/../subject-programs/$SUBJECT_PROGRAM.jar")

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop.
if [[ -n "$TOTAL_TIME" ]]; then
  TIME_LIMIT="$TOTAL_TIME"
else
  TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Map test case to their respective source
declare -A project_src=(
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
JAVA_SRC_DIR=$SRC_BASE_DIR${project_src[$SUBJECT_PROGRAM]}

# Map project names to their respective dependencies
declare -A project_deps=(
  ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
  ["fixsuite-r48"]="$SRC_BASE_DIR/lib/jdom.jar:$SRC_BASE_DIR/lib/log4j-1.2.15.jar:$SRC_BASE_DIR/lib/slf4j-api-1.5.0.jar:$SRC_BASE_DIR/lib/slf4j-log4j12-1.5.0.jar"
  ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
  ["JSAP-2.1"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/" # need to override ant.jar in $SRC_BASE_DIR/lib
  ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
  ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
  ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

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
REPLACEMENT_FILE_PATH="project-config/$SUBJECT_PROGRAM/replacecall-replacements.txt"

# Configure method call replacements to avoid undesired behaviors during test
# generation.
# Map project names to their respective replacement files.
declare -A replacement_files=(
  # Do not wait for user input
  ["jcommander-1.35"]="=--replacement_file=$REPLACEMENT_FILE_PATH"
)
REPLACECALL_COMMAND="$REPLACECALL_JAR${replacement_files[$SUBJECT_PROGRAM]}"

#===============================================================================
# Build System Preparation
#===============================================================================

echo "Modifying build.xml for $SUBJECT_PROGRAM..."
BUILD_FILE="build-$(date +%Y%m%d-%H%M%S)-$$.xml"
(
  # Lock the build.xml file before patching it
  flock 200
  ./apply-build-patch.sh "$SUBJECT_PROGRAM"
  cp "build.xml" "$BUILD_FILE"
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Copied to $BUILD_FILE"
  fi
) 200> "build.xml" # lock on build.xml

(
  cd "$JAVA_SRC_DIR" || exit 1
  if git rev-parse --verify include-major > /dev/null 2>&1; then
    echo "Checking out include-major..."
    git checkout include-major
  fi
)

echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
  touch results/info.csv
  echo -e "RandoopVersion,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

#===============================================================================
# Test Generation & Execution
#===============================================================================

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP); do
  RESULT_DIR="results/$(date +%Y%m%d-%H%M%S)-$GENERATOR-$SUBJECT_PROGRAM"
  mkdir -p "$RESULT_DIR"

  #===============================================================================
  # Generator Command Configuration
  #===============================================================================
  if [[ "$GENERATOR" == "evosuite" ]]; then
    GENERATOR_JAR=$EVOSUITE_JAR
  else
    GENERATOR_JAR=$RANDOOP_JAR
  fi

  declare -A num_classes=(
    ["a4j-1.0b"]=45
    ["asm-5.0.1"]=176
    ["bcel-5.2"]=338
    ["ClassViewer-5.0.5b"]=23
    ["commons-cli-1.2"]=20
    ["commons-codec-1.9"]=76
    ["commons-collections4-4.0"]=390
    ["commons-compress-1.8"]=181
    ["commons-lang3-3.0"]=141
    ["commons-math3-3.2"]=845
    ["commons-primitives-1.0"]=231
    ["dcParseArgs-10.2008"]=6
    ["easymock-3.2"]=79
    ["fixsuite-r48"]=36
    ["guava-16.0.1"]=1,546
    ["hamcrest-core-1.3"]=40
    ["javassist-3.19"]=367
    ["javax.mail-1.5.1"]=284
    ["jaxen-1.1.6"]=175
    ["jcommander-1.35"]=34
    ["jdom-1.0"]=70
    ["joda-time-2.3"]=208
    ["JSAP-2.1"]=69
    ["jvc-1.1"]=24
    ["nekomud-r16"]=8
    ["pmd-core-5.2.2"]=20
    ["sat4j-core-2.3.5"]=213
    ["shiro-core-1.2.3"]=217
    ["slf4j-api-1.7.12"]=18
    ["tinySQL-2.26"]=31
  )
  NUM_CLASSES=${num_classes[$SUBJECT_PROGRAM]}

  # Get the base command using input args
  export JACOCO_AGENT_JAR
  export RESULT_DIR
  export REPLACECALL_JAR
  export REPLACECALL_COMMAND
  export CLASSPATH
  export SRC_JAR
  export GENERATOR_JAR
  export TIME_LIMIT
  export NUM_CLASSES

  GENERATOR_BASE_COMMAND=$("$GENERATOR_DIR"/"$GENERATOR".sh)
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "GENERATOR_BASE_COMMAND=$GENERATOR_BASE_COMMAND"
  fi

  # Add special command suffixes for certain projects.
  # TODO: Add more special cases as needed
  declare -A command_suffix=(
    # Bad inputs generated and caused infinite loops
    ["ClassViewer-5.0.5b"]="--specifications=project-specs/ClassViewer-5.0.5b-specs.json"
    # Bad inputs generated and caused infinite loops
    ["commons-lang3-3.0"]="--specifications=project-specs/commons-lang3-3.0-specs.json"
    # Null Image causes setIconImage to hang
    ["fixsuite-r48"]="--specifications=project-specs/fixsuite-r48-specs.json"
    # An empty BlockingQueue was generated and used but never filled for take(), led to non-termination
    ["guava-16.0.1"]="--specifications=project-specs/guava-16.0.1-specs.json"
    # Randoop generated bad test sequences for handling webserver lifecycle, don't test them
    # ["javassist-3.19"]="--specifications=project-specs/javassist-3.19-specs.json"
    ["javassist-3.19"]="--omit-methods=^javassist\.tools\.web\.Webserver\.run\(\)$ --omit-methods=^javassist\.tools\.rmi\.AppletServer\.run\(\)$"
    # PrintStream.close() maybe called to close System.out, causing Randoop to fail
    ["javax.mail-1.5.1"]="--omit-methods=^java\.io\.PrintStream\.close\(\)$|^java\.io\.FilterOutputStream\.close\(\)$|^java\.io\.OutputStream\.close\(\)$|^com\.sun\.mail\.util\.BASE64EncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QPEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.UUEncoderStream\.close\(\)$"
    # JDOMAbout cannot be found during test.compile, and the class itself isn't interesting
    ["jdom-1.0"]="--omit-classes=^JDOMAbout$"
    # Bad inputs generated and caused infinite loops
    ["jaxen-1.1.6"]="--specifications=project-specs/jaxen-1.1.6-specs.json"
    # Bad inputs cause exceptions in different threads, directly terminating Randoop
    ["sat4j-core-2.3.5"]="--specifications=project-specs/sat4j-core-2.3.5-specs.json"
    # Large inputs to perm take too much time
    ["commons-collections4-4.0"]="--specifications=project-specs/commons-collections4-4.0-specs.json"
    # Bad inputs generated and caused infinite loops
    ["commons-math3-3.2"]="--usethreads=true"
  )

  if [[ "$GENERATOR" == "evosuite" ]]; then
    GENERATOR_COMMAND="$GENERATOR_BASE_COMMAND"
  else
    GENERATOR_COMMAND="$GENERATOR_BASE_COMMAND ${command_suffix[$SUBJECT_PROGRAM]}"
  fi

  # Check if output needs to be redirected for this loop.
  # If the REDIRECT flag is set, redirect all output to a log file for this iteration.
  if [[ "$REDIRECT" -eq 1 ]]; then
    touch mutation_output.txt
    echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
    exec 3>&1 4>&2
    exec 1>> "mutation_output.txt" 2>&1
  fi

  echo "Using $GENERATOR"
  echo
  TEST_DIRECTORY="$CURR_DIR/build/test/$(date +%Y%m%d-%H%M%S)-$GENERATOR"
  mkdir -p "$TEST_DIRECTORY"

  if [[ "$GENERATOR" == "evosuite" ]]; then
    GENERATOR_COMMAND_2="$GENERATOR_COMMAND"
  else
    GENERATOR_COMMAND_2="$GENERATOR_COMMAND --junit-output-dir=$TEST_DIRECTORY"
  fi

  usejdk11
  $GENERATOR_COMMAND_2
  usejdk8

  #===============================================================================
  # Coverage & Mutation Analysis
  #===============================================================================
  echo
  echo "Compiling and mutating project..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo command:
    echo "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile
  fi
  echo
  "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile

  echo
  echo "Compiling tests..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo command:
    echo "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests
  fi
  echo
  "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests

  echo
  echo "Running tests with coverage..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo command:
    echo "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" test
  fi
  echo
  "$MAJOR_HOME"/bin/ant -f "$BUILD_FILE" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" test

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
  # Handling concurrency: redirect results/*.csv files from mutation score
  "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test &
  ANT_PID=$!
  ANT_UID=$(ps -o uid= -p "$ANT_PID" 2> /dev/null)
  echo "ANT_PID/UID: $ANT_PID $ANT_UID"

  # Monitor ant's created files and redirect
  inotifywait -m -r -e close_write,create --format "%w%f" "$SCRIPT_DIR/results" | while read FILE; do
    if [ -f "$FILE" ]; then
      FILE_UID=$(stat -c %u "$FILE") # Get the owner UID
      if [[ "$VERBOSE" -eq 1 ]]; then
        echo "Checking file: $FILE (UID: $FILE_UID)"
      fi
      if [ "$FILE_UID" -eq "$ANT_UID" ]; then
        mv "$FILE" "$RESULT_DIR"/ 2> /dev/null && echo "Moved $FILE to $RESULT_DIR"
      fi
    fi
  done &
  MONITOR_PID=$!
  wait "$ANT_PID"
  kill "$MONITOR_PID"

  # Calculate Mutation Score
  mutants_covered=$(awk -F, 'NR==2 {print $3}' "$RESULT_DIR"/summary.csv)
  mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULT_DIR"/summary.csv)
  mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
  mutation_score=$(printf "%.2f" "$mutation_score")

  echo "Instruction Coverage: $instruction_coverage%"
  echo "Branch Coverage: $branch_coverage%"
  echo "Mutation Score: $mutation_score%"

  row="$GENERATOR,$(basename "$SRC_JAR"),$TIME_LIMIT,0,$instruction_coverage%,$branch_coverage%,$mutation_score%"
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

  echo "Results will be saved in $RESULT_DIR"
  # Move all output files into the results/ directory.
  # WARNING: These are subject to race conditions
  # suppression.log may be in one of two locations depending on if using include-major branch
  mv "$JAVA_SRC_DIR"/suppression.log "$RESULT_DIR" 2> /dev/null || true
  mv suppression.log "$RESULT_DIR" 2> /dev/null || true
done

#===============================================================================
# Build System Cleanup
#===============================================================================
echo
echo "Restoring build.xml"
# restore build.xml
(
  # Lock the build.xml file before patching it
  flock 200
  ./apply-build-patch.sh > /dev/null
  rm "$BUILD_FILE"
) 200> "build.xml" # lock on build.xml

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(
  cd "$JAVA_SRC_DIR"
  git checkout main 1> /dev/null
)
