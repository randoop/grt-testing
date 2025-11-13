#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# This script:
#  * Generates test suites using EvoSuite.
#  * Computes mutation score (mutants are generated using Major via ant).
#  * Computes code coverage (using Jacoco via Maven).
#
# Directories and files:
# - `build/evosuite-tests*`: EvoSuite-created test suites.
# - `build/bin`: Compiled tests and code.
# - `results/$RESULTS_CSV`: CSV file containing summary statistics for each iteration (see -o flag)
# - `results/`: everything else specific to the most recent iteration.

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
#   ./mutation-evosuite.sh -c 1 -o info.csv commons-lang3-3.0

#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
USAGE_STRING="usage: mutation-evosuite.sh [-o RESULTS_CSV] [-t total_time] [-c time_per_class] [-n num_iterations] [-r] [-v] [-h] TEST-CASE-NAME
  -o N  Csv output filename; should end in \".csv\"; if relative, should not include a directory name.
  -t N  Total time limit for test generation (in seconds).
  -c N  Per-class time limit (in seconds, default: 2s/class).
        Mutually exclusive with -t.
  -n N  Number of iterations to run the experiment (default: 1).
  -r    Redirect logs and diagnostics to results/result/mutation_output.txt.
  -v    Enables verbose mode.
  -h    Displays this help message.
  TEST-CASE-NAME is the name of a jar file in ../subject-programs/, without .jar.
  Example: commons-lang3-3.0"

#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `prerequisites.md`.

# Fail this script on errors.
set -e
set -o pipefail

#===============================================================================
# Environment Setup
#===============================================================================

# Requires Java 8
JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{sub("^$", "0", $2); print $1$2}')
if [[ "$JAVA_VER" -ne 18 ]]; then
  echo "Error: Java version 8 is required. Please install it and try again."
  exit 2
fi

Generator=EvoSuite
generator=evosuite
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
SCRIPT_NAME=$(basename -- "$0")
MAJOR_HOME=$(realpath "${SCRIPT_DIR}/build/major/")               # Major home directory, for mutation testing
EVOSUITE_JAR=$(realpath "${SCRIPT_DIR}/build/evosuite-1.2.0.jar") # EvoSuite jar file
JACOCO_CLI_JAR=$(realpath "${SCRIPT_DIR}/build/jacococli.jar")    # For coverage report generation

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

if [ $# -eq 0 ]; then
  echo "${SCRIPT_NAME}: $USAGE_STRING"
  exit 2
fi

NUM_LOOP=1      # Number of experiment runs (10 in GRT paper)
VERBOSE=0       # Verbose option
REDIRECT=0      # Redirect output to mutation_output.txt
UUID=$(uuidgen) # Generate a unique identifier per instance

# Parse command-line arguments
while getopts ":hvro:t:c:n:" opt; do
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
      RESULTS_CSV="$OPTARG"
      ;;
    t)
      # Total experiment time, mutually exclusive with SECONDS_PER_CLASS
      TOTAL_TIME="$OPTARG"
      ;;
    c)
      # Default seconds per class.
      # The paper runs Randoop/EvoSuite with 4 different time limits:
      # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.
      SECONDS_PER_CLASS="$OPTARG"
      ;;
    n)
      # Number of iterations to run the experiment
      NUM_LOOP="$OPTARG"
      ;;
    \?)
      echo "${SCRIPT_NAME}: invalid option: -$OPTARG" >&2
      echo "$USAGE_STRING"
      exit 2
      ;;
    :)
      echo "${SCRIPT_NAME}: option -$OPTARG requires an argument." >&2
      echo "$USAGE_STRING"
      exit 2
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ -z "$RESULTS_CSV" ]]; then
  echo "${SCRIPT_NAME}: No -o command-line argument given."
  exit 2
fi

# Enforce that mutually exclusive options are not bundled together
if [[ -n "$TOTAL_TIME" ]] && [[ -n "$SECONDS_PER_CLASS" ]]; then
  echo "${SCRIPT_NAME}: Options -t and -c cannot be used together in any form (e.g., -t -c)."
  exit 2
fi

# Default to 2 seconds per class if not specified
if [[ -z "$SECONDS_PER_CLASS" ]] && [[ -z "$TOTAL_TIME" ]]; then
  SECONDS_PER_CLASS=2
fi

# Name of the subject program.
SUBJECT_PROGRAM="$1"

ANT="ant"

echo "Running mutation test on $SUBJECT_PROGRAM"
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

# Time limit for running the test generator.
if [[ -n "$TOTAL_TIME" ]]; then
  # If TOTAL_TIME is set, we need to calculate a per-class time budget.
  # This is because EvoSuite's -Dsearch_budget option applies time limits per class,
  # so we need to convert the total budget into a per-class value.

  # Use awk to divide TOTAL_TIME by NUM_CLASSES and round up to the nearest integer.
  # This ensures our per-class number is not less than 1 second.
  result=$(awk -v t="$TOTAL_TIME" -v n="$NUM_CLASSES" 'BEGIN {
        r = t / n;
        # If calculated time per class is less than 1 second, set it to 1
        if (r < 1) print 1;
        # Otherwise, round up the result (simulate ceiling function)
        else print int(r + 0.999)
    }')

  TIME_LIMIT=$result
else
  TIME_LIMIT=$SECONDS_PER_CLASS
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Map subject programs to their source directories.
# Subject programs not listed here default to top-level source directory ($SRC_BASE_DIR).
declare -A program_src=(
  ["a4j-1.0b"]="/src/"
  ["asm-5.0.1"]="/src/main/java/"
  ["bcel-5.2"]="/src/java/"
  ["commons-codec-1.9"]="/src/main/java/"
  ["commons-cli-1.2"]="/src/java/"
  ["commons-collections4-4.0"]="/src/main/java/"
  ["commons-compress-1.8"]="/src/main/java/"
  ["commons-lang3-3.0"]="/src/main/java/"
  ["commons-math3-3.2"]="/src/main/java/"
  ["commons-primitives-1.0"]="/src/java/"
  ["dcParseArgs-10.2008"]="/src/"
  ["easymock-3.2"]="/easymock/src/main/java/"
  ["fixsuite-r48"]="/library/"
  ["guava-16.0.1"]="/src/"
  ["hamcrest-core-1.3"]="/hamcrest-core/src/main/java/"
  ["javassist-3.19"]="/src/main/"
  ["javax.mail-1.5.1"]="/src/main/java/"
  ["jaxen-1.1.6"]="/src/java/main/"
  ["jcommander-1.35"]="/src/main/java/"
  ["jdom-1.0"]="/src/java/"
  ["joda-time-2.3"]="/src/main/java/"
  ["JSAP-2.1"]="/src/java/"
  ["jvc-1.1"]="/src/"
  ["nekomud-r16"]="/src/"
  ["sat4j-core-2.3.5"]="/org.sat4j.core/src/main/java/"
  ["shiro-core-1.2.3"]="/core/src/main/java/"
  ["slf4j-api-1.7.12"]="/slf4j-api/src/main/java/"
  ["pmd-core-5.2.2"]="/pmd-core/src/main/java/"
)
JAVA_SRC_DIR=$SRC_BASE_DIR${program_src[$SUBJECT_PROGRAM]}

#===============================================================================
# Subject Program Specific Dependencies
#===============================================================================

setup_build_dir() {
  rm -rf "$SCRIPT_DIR/build/lib/$UUID"
  mkdir -p "$SCRIPT_DIR/build/lib/$UUID"
  copy_jars "$SRC_JAR"
}

download_jars() {
  for url in "$@"; do
    wget -P "$SCRIPT_DIR/build/lib/$UUID" "$url"
  done
}

copy_jars() {
  for path in "$@"; do
    cp -r "$path" "$SCRIPT_DIR/build/lib/$UUID"
  done
}

case "$SUBJECT_PROGRAM" in
  "a4j-1.0b")
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/jars/jox116.jar" \
      "$SRC_BASE_DIR/jars/log4j-1.2.4.jar"
    ;;
  "commons-compress-1.8")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/org/tukaani/xz/1.5/xz-1.5.jar"
    ;;

  "easymock-3.2")
    setup_build_dir
    download_jars \
      "https://repo1.maven.org/maven2/com/google/dexmaker/dexmaker/1.0/dexmaker-1.0.jar" \
      "https://repo1.maven.org/maven2/org/objenesis/objenesis/1.3/objenesis-1.3.jar" \
      "https://repo1.maven.org/maven2/cglib/cglib-nodep/2.2.2/cglib-nodep-2.2.2.jar" \
      "https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar"
    ;;

  "fixsuite-r48")
    # For EvoSuite, mutation analysis doesn't work if slf4j-log4j12-1.5.2.jar is on the classpath
    # However, Randoop needs this dependency.
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/lib/jdom.jar" \
      "$SRC_BASE_DIR/lib/log4j-1.2.15.jar" \
      "$SRC_BASE_DIR/lib/slf4j-api-1.5.0.jar"
    ;;

  "guava-16.0.1")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar"
    ;;

  "javassist-3.19")
    setup_build_dir
    copy_jars "$JAVA_HOME/lib/tools.jar"
    ;;

  "jaxen-1.1.6")
    setup_build_dir
    download_jars \
      "https://repo1.maven.org/maven2/dom4j/dom4j/1.6.1/dom4j-1.6.1.jar" \
      "https://repo1.maven.org/maven2/jdom/jdom/1.0/jdom-1.0.jar" \
      "https://repo1.maven.org/maven2/xml-apis/xml-apis/1.3.02/xml-apis-1.3.02.jar" \
      "https://repo1.maven.org/maven2/xerces/xercesImpl/2.6.2/xercesImpl-2.6.2.jar" \
      "https://repo1.maven.org/maven2/xom/xom/1.0/xom-1.0.jar" \
      "https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar"
    ;;

  "jdom-1.0")
    setup_build_dir
    copy_jars \
      "$MAJOR_HOME/lib/ant" \
      "$SRC_BASE_DIR/lib/xml-apis.jar" \
      "$SRC_BASE_DIR/lib/xerces.jar" \
      "$SRC_BASE_DIR/lib/jaxen-core.jar" \
      "$SRC_BASE_DIR/lib/jaxen-jdom.jar" \
      "$SRC_BASE_DIR/lib/saxpath.jar" \
      "$SCRIPT_DIR/../subject-programs/jaxen-1.1.6.jar"
    ;;

  "joda-time-2.3")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/org/joda/joda-convert/1.2/joda-convert-1.2.jar"
    ;;

  "JSAP-2.1")
    setup_build_dir
    copy_jars \
      "$MAJOR_HOME/lib/ant" \
      "$SRC_BASE_DIR/lib/ant.jar" \
      "$SRC_BASE_DIR/lib/xstream-1.1.2.jar" \
      "$SRC_BASE_DIR/lib/rundoc-0.11.jar" \
      "$SRC_BASE_DIR/lib/snip-0.11.jar"
    ;;

  "jvc-1.1")
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/lib/jsp-api-2.1.jar" \
      "$SRC_BASE_DIR/lib/junit-4.12.jar" \
      "$SRC_BASE_DIR/lib/log4j-1.2.15.jar" \
      "$SRC_BASE_DIR/lib/servlet-api-2.5.jar"
    ;;

  "nekomud-r16")
    # For EvoSuite, mutation analysis doesn't work if slf4j-log4j12-1.5.2.jar is on the classpath
    # However, Randoop needs this dependency.
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/lib/aspectjweaver.jar" \
      "$SRC_BASE_DIR/lib/cglib-nodep-2.1_3.jar" \
      "$SRC_BASE_DIR/lib/freemarker.jar" \
      "$SRC_BASE_DIR/lib/jcl-over-slf4j-1.5.2.jar" \
      "$SRC_BASE_DIR/lib/junit-4.12.jar" \
      "$SRC_BASE_DIR/lib/log4j-1.2.15.jar" \
      "$SRC_BASE_DIR/lib/slf4j-api-1.5.2.jar" \
      "$SRC_BASE_DIR/lib/spring-test.jar" \
      "$SRC_BASE_DIR/lib/spring.jar"
    ;;

  "pmd-core-5.2.2")
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/pmd-core/lib/asm-9.7.jar"
    ;;

  "sat4j-core-2.3.5")
    setup_build_dir
    copy_jars \
      "$SRC_BASE_DIR/lib/commons-beanutils.jar" \
      "$SRC_BASE_DIR/lib/commons-cli.jar" \
      "$SRC_BASE_DIR/lib/commons-logging.jar" \
      "$SRC_BASE_DIR/lib/jchart2d-3.2.2.jar" \
      "$SRC_BASE_DIR/lib/mockito-all-1.9.5.jar"
    ;;

  "shiro-core-1.2.3")
    setup_build_dir
    download_jars \
      "https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.8.3/commons-beanutils-1.8.3.jar" \
      "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar" \
      "https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.7.25/slf4j-simple-1.7.25.jar"
    ;;

  *)
    setup_build_dir
    ;;
esac

#===============================================================================
# Test generator command configuration
#===============================================================================
EVOSUITE_CLASSPATH="$(echo "$SCRIPT_DIR/build/lib/$UUID/"*.jar | tr ' ' ':')"
TARGET_JAR="$SCRIPT_DIR/build/lib/$UUID/$SUBJECT_PROGRAM.jar"

EVOSUITE_BASE_COMMAND=(
  java
  -jar "$EVOSUITE_JAR"
  -target "$TARGET_JAR"
  -projectCP "$EVOSUITE_CLASSPATH:$EVOSUITE_JAR"
  -Dsearch_budget="$TIME_LIMIT"
  -Drandom_seed=0
  -Dreplace_gui=true
)

#===============================================================================
# Build System Preparation
#===============================================================================
echo "Using ${Generator} to generate tests."
echo

# Handle relative and absolute output files; make sure output file exists.
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"
RESULTS_CSV=$(cd "$RESULTS_DIR" && realpath "$RESULTS_CSV")
if [ ! -f "$RESULTS_CSV" ]; then
  echo -e "Version,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > "$RESULTS_CSV"
fi

#===============================================================================
# Test Generation & Execution
#===============================================================================

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 "$NUM_LOOP"); do

  # This suffix is unique to each instance of this script. We use it to prevent concurrency issues between processes.
  FILE_SUFFIX="$SUBJECT_PROGRAM-EVOSUITE-$UUID"

  # Test directory for each iteration.
  TEST_DIRECTORY="$SCRIPT_DIR/build/$generator-tests/$FILE_SUFFIX"
  rm -rf "$TEST_DIRECTORY"
  mkdir -p "$TEST_DIRECTORY"

  # Evosuite report directory for each iteration
  REPORT_DIRECTORY="$SCRIPT_DIR/build/evosuite-report/$FILE_SUFFIX"
  rm -rf "$REPORT_DIRECTORY"
  mkdir -p "$REPORT_DIRECTORY"

  # Jacoco directory for each iteration
  COVERAGE_DIRECTORY="$SCRIPT_DIR/build/target/$FILE_SUFFIX"
  rm -rf "$COVERAGE_DIRECTORY"
  mkdir -p "$COVERAGE_DIRECTORY"

  # Result directory for each test generation and execution.
  RESULT_DIR="$SCRIPT_DIR/results/$FILE_SUFFIX"
  rm -rf "$RESULT_DIR"
  mkdir -p "$RESULT_DIR"

  # If the REDIRECT flag is set, redirect all output to a log file.
  if [[ "$REDIRECT" -eq 1 ]]; then
    touch "$RESULT_DIR"/mutation_output.txt
    echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
    exec 3>&1 4>&2
    exec 1>> "$RESULT_DIR"/mutation_output.txt 2>&1
  fi

  cd "$RESULT_DIR"

  GENERATOR_COMMAND=(
    "${EVOSUITE_BASE_COMMAND[@]}"
    -Dtest_dir="$TEST_DIRECTORY"
    -Dreport_dir="$REPORT_DIRECTORY"
  )

  "${GENERATOR_COMMAND[@]}"

  # After test generation, for JSAP-2.1, we need to remove the ant.jar from the classpath
  if [[ "$SUBJECT_PROGRAM" == "JSAP-2.1" ]]; then
    rm "$SCRIPT_DIR/build/lib/$UUID/ant.jar"
  fi

  #===============================================================================
  # Coverage & Mutation Analysis
  #===============================================================================

  buildfile="build-$generator.xml"

  echo
  echo "Compiling and mutating subject program..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo compile.mutation command:
    echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.mutation
    echo compile.jacoco command:
    echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.jacoco
  fi
  echo
  "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.mutation
  "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.jacoco

  echo
  echo "Compiling tests..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo compile.mutation.tests command:
    echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.mutation.tests
    echo compile.jacoco.tests command:
    echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.jacoco.tests
  fi
  echo
  "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.mutation.tests
  "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" compile.jacoco.tests

  echo
  echo "Running tests with coverage..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo command:
    echo "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" test
  fi
  echo
  "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dtargetdir="$COVERAGE_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" test

  java -jar "$JACOCO_CLI_JAR" report "$RESULT_DIR/jacoco.exec" --classfiles "$COVERAGE_DIRECTORY/classes" --sourcefiles "$JAVA_SRC_DIR" --csv "$RESULT_DIR"/report.csv

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

  # For jdom-1.0, we need to convert the generated tests from EvoSuite format to Randoop format.
  # This is because the EvoSuite runner inteferes with the bytecode manipulation done by Major,
  # resulting in a lot of methods being excluded from mutation analysis.
  # We use a Python script to convert the tests.
  if [ "$SUBJECT_PROGRAM" == "jdom-1.0" ]; then
    PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
    if [ -z "$PYTHON_EXECUTABLE" ]; then
      echo "Error: Python is not installed." >&2
      exit 2
    fi
    "$PYTHON_EXECUTABLE" "$SCRIPT_DIR"/convert_test_runners.py "$TEST_DIRECTORY" --mode evosuite-to-randoop
  fi

  echo
  echo "Running tests with mutation analysis..."
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo command:
    echo "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" mutation.test
  fi
  echo
  "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/${buildfile} -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dlibdir="$SCRIPT_DIR/build/lib/$UUID" mutation.test

  # Calculate Mutation Score
  mutants_generated=$(awk -F, 'NR==2 {print $1}' "$RESULT_DIR"/summary.csv)
  mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULT_DIR"/summary.csv)
  mutation_score=$(echo "scale=4; $mutants_killed / $mutants_generated * 100" | bc)
  mutation_score=$(printf "%.2f" "$mutation_score")

  echo "Instruction Coverage: $instruction_coverage%"
  echo "Branch Coverage: $branch_coverage%"
  echo "Mutation Score: $mutation_score%"

  # Determine time limit to log: use TOTAL_TIME if specified, otherwise use SECONDS_PER_CLASS.
  if [[ -n "$TOTAL_TIME" ]]; then
    LOGGED_TIME="$TOTAL_TIME"
  else
    LOGGED_TIME="$SECONDS_PER_CLASS"
  fi
  row="EVOSUITE,$(basename "$SRC_JAR"),$LOGGED_TIME,0,$instruction_coverage,$branch_coverage,$mutation_score"
  # $RESULTS_CSV is a csv file that contains a record of each pass.
  # On Unix, ">>" is generally atomic as long as the content is small enough
  # (usually the limit is at least 1024).
  echo -e "$row" >> "$RESULTS_CSV"

  # Copy the test suites to results directory
  echo "Copying test suites to results directory..."
  cp -r "$TEST_DIRECTORY" "$RESULT_DIR"

  if [[ "$REDIRECT" -eq 1 ]]; then
    exec 1>&3 2>&4
    exec 3>&- 4>&-
  fi

  cd "$SCRIPT_DIR"
done

#===============================================================================
# Build System Cleanup
#===============================================================================

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(
  cd "$JAVA_SRC_DIR"
  git checkout main 1> /dev/null
)
