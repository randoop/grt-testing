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

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
#   ./mutation.sh -c 1 commons-lang3-3.0

#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
# See variable USAGE_STRING below

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

USAGE_STRING="usage: mutation.sh [-h] [-v] [-r] [-f features] [-a] [-t total_time] [-c time_per_class] [-n num_iterations] TEST-CASE-NAME
  -h    Displays this help message.
  -v    Enables verbose mode.
  -r    Redirect Randoop and Major output to results/result/mutation_output.txt.
  -f    Specify the features to use.
        Available features: BASELINE, BLOODHOUND, ORIENTEERING, BLOODHOUND_AND_ORIENTEERING, DETECTIVE, GRT_FUZZING, ELEPHANT_BRAIN, CONSTANT_MINING.
        example usage: -f BASELINE,BLOODHOUND
  -a    Perform feature ablation studies.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
MAJOR_HOME=$(realpath "${SCRIPT_DIR}/build/major/")                 # Major home directory, for mutation testing
RANDOOP_JAR=$(realpath "${SCRIPT_DIR}/build/randoop-all-4.3.3.jar") # Randoop jar file
JACOCO_AGENT_JAR=$(realpath "${SCRIPT_DIR}/build/jacocoagent.jar")  # For Bloodhound
JACOCO_CLI_JAR=$(realpath "${SCRIPT_DIR}/build/jacococli.jar")      # For coverage report generation
REPLACECALL_JAR=$(realpath "build/replacecall-4.3.3.jar")           # For replacing undesired method calls

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================

NUM_LOOP=1     # Number of experiment runs (10 in GRT paper)
VERBOSE=0      # Verbose option
REDIRECT=0     # Redirect output to mutation_output.txt
ABLATION=false # Feature ablation option
UUID=$(uuidgen) # Generate a unique identifier per instance

# Parse command-line arguments
while getopts ":hvrf:at:c:n:" opt; do
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
    f)
      FEATURES_OPT="$OPTARG"
      ;;
    a)
      ABLATION=true
      ;;
    t)
      # Total experiment time, mutually exclusive with SECONDS_PER_CLASS
      TOTAL_TIME="$OPTARG"
      ;;
    c)
      # Default seconds per class.
      # The paper runs Randoop with 4 different time limits:
      # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.
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

# Enforce that mutually exclusive options are not bundled together
if [[ -n "$TOTAL_TIME" ]] && [[ -n "$SECONDS_PER_CLASS" ]]; then
  echo "Options -t and -c cannot be used together in any form (e.g., -t -c)."
  exit 1
fi

# Default to 2 seconds per class if not specified
if [[ -z "$SECONDS_PER_CLASS" ]] && [[ -z "$TOTAL_TIME" ]]; then
  SECONDS_PER_CLASS=2
fi

# Name of the subject program.
SUBJECT_PROGRAM="$1"

ALL_RANDOOP_FEATURES=("BASELINE" "BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
if [[ -n "$FEATURES_OPT" ]]; then
  IFS=',' read -r -a RANDOOP_FEATURES <<< "$FEATURES_OPT"
else
  RANDOOP_FEATURES=("BASELINE")
fi

# validate
for feat in "${RANDOOP_FEATURES[@]}"; do
  if [[ ! " ${ALL_RANDOOP_FEATURES[*]} " =~ ${feat} ]]; then
    echo "ERROR: unknown feature: $feat"
    exit 1
  fi
done

# Select the ant executable based on the subject program
if [ "$SUBJECT_PROGRAM" == "bcel-5.2" ] || [ "$SUBJECT_PROGRAM" = "ClassViewer-5.0.5b" ] || [ "$SUBJECT_PROGRAM" = "jcommander-1.35" ] || [ "$SUBJECT_PROGRAM" = "fixsuite-r48" ]; then
  ANT="ant-replacecall"
  chmod +x "$MAJOR_HOME"/bin/ant-replacecall
else
  ANT="ant"
fi

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

# Map subject programs to their dependencies
declare -A program_deps=(
  ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
  ["commons-compress-1.8"]="$SCRIPT_DIR/build/lib/"
  ["easymock-3.2"]="$SCRIPT_DIR/build/lib/"
  ["fixsuite-r48"]="$SRC_BASE_DIR/lib/"
  ["guava-16.0.1"]="$SCRIPT_DIR/build/lib/"
  ["hamcrest-core-1.3"]="$SCRIPT_DIR/build/lib/"
  ["javassist-3.19"]="$SCRIPT_DIR/build/lib/"
  ["jaxen-1.1.6"]="$SCRIPT_DIR/build/lib/"
  ["jdom-1.0"]="$SCRIPT_DIR/build/lib/"
  ["joda-time-2.3"]="$SCRIPT_DIR/build/lib/"
  ["JSAP-2.1"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/" # need to override ant.jar in $SRC_BASE_DIR/lib
  ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
  ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
  ["pmd-core-5.2.2"]="$SRC_BASE_DIR/pmd-core/lib"
  ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
  ["shiro-core-1.2.3"]="$SCRIPT_DIR/build/lib/"
)

#===============================================================================
# Subject Program Specific Dependencies
#===============================================================================
setup_build_dir() {
  rm -rf $SCRIPT_DIR/build/lib
  mkdir -p $SCRIPT_DIR/build/lib
}

download_jars() {
  for url in "$@"; do
    wget -P $SCRIPT_DIR/build/lib "$url"
  done
}

copy_jars() {
  for path in "$@"; do
    cp -r "$path" $SCRIPT_DIR/build/lib
  done
}

case "$SUBJECT_PROGRAM" in
  "commons-compress-1.8")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/org/tukaani/xz/1.5/xz-1.5.jar"
    ;;

  "easymock-3.2")
    setup_build_dir
    download_jars \
      "https://repo1.maven.org/maven2/com/google/dexmaker/dexmaker/1.0/dexmaker-1.0.jar" \
      "https://repo1.maven.org/maven2/org/objenesis/objenesis/1.3/objenesis-1.3.jar" \
      "https://repo1.maven.org/maven2/cglib/cglib-nodep/2.2.2/cglib-nodep-2.2.2.jar"
    ;;

  "guava-16.0.1")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar"
    ;;

  "hamcrest-core-1.3")
    setup_build_dir
    download_jars "https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-1.2.0.jar"
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
      "$SRC_BASE_DIR/lib/saxpath.jar"
    ;;

  "joda-time-2.3")
    setup_build_dir
    download_jars "https://repo1.maven.org/maven2/org/joda/joda-convert/1.2/joda-convert-1.2.jar"
    ;;

  "shiro-core-1.2.3")
    setup_build_dir
    download_jars \
      "https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.8.3/commons-beanutils-1.8.3.jar" \
      "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar"
    ;;

  *) ;;

esac

CLASSPATH="$SRC_JAR"
if [[ -n "${program_deps[$SUBJECT_PROGRAM]}" ]]; then
  CLASSPATH="$CLASSPATH:${program_deps[$SUBJECT_PROGRAM]}"
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  echo "JAVA_SRC_DIR: $JAVA_SRC_DIR"
  echo "CLASSPATH: $CLASSPATH"
  echo
fi

#===============================================================================
# Method Call Replacement Setup
#===============================================================================
# Path to the replacement file for the replacecall agent.
REPLACEMENT_FILE_PATH="$SCRIPT_DIR/program-config/$SUBJECT_PROGRAM/replacecall-replacements.txt"

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
RANDOOP_CLASSPATH="$CLASSPATH"
if [[ -n "${program_deps[$SUBJECT_PROGRAM]}" ]]; then
  RANDOOP_CLASSPATH+="*"
fi

RANDOOP_BASE_COMMAND="java \
-Xbootclasspath/a:$JACOCO_AGENT_JAR:$REPLACECALL_JAR \
-javaagent:$JACOCO_AGENT_JAR \
-javaagent:$REPLACECALL_COMMAND \
-classpath $RANDOOP_CLASSPATH:$RANDOOP_JAR \
randoop.main.Main gentests \
--testjar=$SRC_JAR \
--time-limit=$TIME_LIMIT \
--deterministic=false \
--no-error-revealing-tests=true \
--randomseed=0"

# Add special command suffixes for specific subject programs
declare -A command_suffix=(
  # Specify valid inputs to prevent infinite loops during test generation/execution
  ["ClassViewer-5.0.5b"]="--specifications=$SCRIPT_DIR/program-specs/ClassViewer-5.0.5b-specs.json --omit-methods=^com\.jstevh\.viewer\.ClassViewer\.callBrowser\(java\.lang\.String\)$"
  ["commons-cli-1.2"]="--specifications=$SCRIPT_DIR/program-specs/commons-cli-1.2-specs.json"
  ["commons-lang3-3.0"]="--specifications=$SCRIPT_DIR/program-specs/commons-lang3-3.0-specs.json"
  ["guava-16.0.1"]="--specifications=$SCRIPT_DIR/program-specs/guava-16.0.1-specs.json"
  ["jaxen-1.1.6"]="--specifications=$SCRIPT_DIR/program-specs/jaxen-1.1.6-specs.json"

  # Randoop generates bad sequences for handling webserver lifecycle, don't test them
  ["javassist-3.19"]="--omit-methods=^javassist\.tools\.web\.Webserver\.run\(\)$ --omit-methods=^javassist\.tools\.rmi\.AppletServer\.run\(\)$"
  # PrintStream.close() is called to close System.out during Randoop test generation.
  # This will interrupt the test generation process. Omit the close() method.
  ["javax.mail-1.5.1"]="--omit-methods=^java\.io\.PrintStream\.close\(\)$|^java\.io\.FilterOutputStream\.close\(\)$|^java\.io\.OutputStream\.close\(\)$|^com\.sun\.mail\.util\.BASE64EncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.QPEncoderStream\.close\(\)$|^com\.sun\.mail\.util\.UUEncoderStream\.close\(\)$ --usethreads=true"
  # JDOMAbout cannot be found during test.compile.
  ["jdom-1.0"]="--omit-classes=^JDOMAbout$"

  # Long execution time due to excessive computation for some inputs.
  # Specify input range to reduce computation and test execution time.
  ["commons-collections4-4.0"]="--specifications=$SCRIPT_DIR/program-specs/commons-collections4-4.0-specs.json"
  # Force termination if a test case takes too long to execute
  ["commons-math3-3.2"]="--usethreads=true"
  ["nekomud-r16"]="--omit-methods=^net\.sourceforge\.nekomud\.service\.NetworkService\.stop\(\)$"
)

# Check if the environment is headless. If it is, we can't use the spec for fixsuite-r48 due to initialization errors.
if [ -z "$DISPLAY" ] && [ "$SUBJECT_PROGRAM" == "fixsuite-r48" ]; then
  echo "Running in headless mode. Avoiding spec for fixsuite-r48..."
else
  # Only add fixsuite-r48 specification if not headless
  command_suffix["fixsuite-r48"]="--specifications=$SCRIPT_DIR/program-specs/fixsuite-r48-specs.json"
fi

RANDOOP_COMMAND="$RANDOOP_BASE_COMMAND ${command_suffix[$SUBJECT_PROGRAM]}"

#===============================================================================
# Build System Preparation
#===============================================================================
cd "$JAVA_SRC_DIR" || exit 1

# For slf4j-api-1.7.12 and javax.mail, this Randoop script uses the main branch, which retains the default namespaces (e.g., org.slf4j, javax.mail),
# since Randoop does not restrict test generation based on package names.
#
# However, EvoSuite contains hardcoded checks that prevent test generation for certain core namespaces like org.slf4j and javax.mail.
# To work around this, the EvoSuite script (which will eventually be merged) uses the include-major branch,
# where the packages have been renamed to org1.slf4j and javax1.mail.
#
# The EvoSuite script will also temporarily modifies the corresponding source jarfile to reflect this namespace change during test generation,
# and then restores the original JARs afterward to maintain consistency.
if [ "$SUBJECT_PROGRAM" != "slf4j-api-1.7.12" ] && [ "$SUBJECT_PROGRAM" != "javax.mail-1.5.1" ]; then
  if git checkout include-major > /dev/null 2>&1; then
    echo "Checked out include-major."
  fi
fi
cd - || exit 1

echo "Using Randoop to generate tests."
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

# The value for the -lib command-line option; that is, the classpath.
LIB_ARG="$CLASSPATH"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 "$NUM_LOOP"); do
  for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}"; do

    FEATURE_NAME=""
    if [[ "$ABLATION" == "true" ]]; then
      FEATURE_NAME="ALL-EXCEPT-$RANDOOP_FEATURE"
    else
      FEATURE_NAME="$RANDOOP_FEATURE"
    fi
    echo "Using $FEATURE_NAME"
    echo

    # This suffix is unique to each instance of this script. We use it to prevent concurrency issues between processes.
    FILE_SUFFIX="$SUBJECT_PROGRAM-$FEATURE_NAME-$UUID"

    # Test directory for each iteration.
    TEST_DIRECTORY="$SCRIPT_DIR/build/test/$FILE_SUFFIX"
    mkdir -p "$TEST_DIRECTORY"

    # Result directory for each test generation and execution.
    RESULT_DIR="$SCRIPT_DIR/results/$FILE_SUFFIX"
    mkdir -p "$RESULT_DIR"

    # If the REDIRECT flag is set, redirect all output to a log file.
    if [[ "$REDIRECT" -eq 1 ]]; then
      touch "$RESULT_DIR"/mutation_output.txt
      echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
      exec 3>&1 4>&2
      exec 1>> "$RESULT_DIR"/mutation_output.txt 2>&1
    fi

    # Bloodhound
    if [[ ("$RANDOOP_FEATURE" == "BLOODHOUND" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "BLOODHOUND" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--method-selection=BLOODHOUND"
    fi

    # Baseline
    if [[ ("$RANDOOP_FEATURE" == "BASELINE" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "BASELINE" && "$ABLATION" == "true") ]]; then
      ## There is nothing to do in this case.
      # FEATURE_FLAG=""
      true
    fi

    # Orienteering
    if [[ ("$RANDOOP_FEATURE" == "ORIENTEERING" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "ORIENTEERING" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--input-selection=ORIENTEERING"
    fi

    # Bloodhound and Orienteering
    if [[ ("$RANDOOP_FEATURE" == "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--input-selection=ORIENTEERING --method-selection=BLOODHOUND"
    fi

    # Detective (Demand-Driven)
    if [[ ("$RANDOOP_FEATURE" == "DETECTIVE" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "DETECTIVE" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--demand-driven=true"
    fi

    # GRT Fuzzing
    if [[ ("$RANDOOP_FEATURE" == "GRT_FUZZING" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "GRT_FUZZING" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--grt-fuzzing=true"
    fi

    # Elephant Brain
    if [[ ("$RANDOOP_FEATURE" == "ELEPHANT_BRAIN" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "ELEPHANT_BRAIN" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--elephant-brain=true"
    fi

    # Constant Mining
    if [[ ("$RANDOOP_FEATURE" == "CONSTANT_MINING" && "$ABLATION" != "true") ||
      ("$RANDOOP_FEATURE" != "CONSTANT_MINING" && "$ABLATION" == "true") ]]; then
      FEATURE_FLAG="--constant-mining=true"
    fi

    # We cd into the result directory because Randoop generates jacoco.exec in the directory which it is run.
    # This is a concurrency issue since multiple runs will output a jacoco file to the exact same spot.
    # Each result directory is unique to each instance of this script.
    cd $RESULT_DIR

    # shellcheck disable=SC2086 # FEATURE_FLAG may contain multiple arguments.
    $RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY $FEATURE_FLAG

    #===============================================================================
    # Coverage & Mutation Analysis
    #===============================================================================

    echo
    echo "Compiling and mutating subject program..."
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo command:
      echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile
    fi
    echo
    "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile

    echo
    echo "Compiling tests..."
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo command:
      echo "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests
    fi
    echo
    "$MAJOR_HOME"/bin/ant -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests

    echo
    echo "Running tests with coverage..."
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo command:
      echo "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" test
    fi
    echo
    "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" test

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

    # For hamcrest-core-1.3, we need to run the generated tests with EvoSuite's runner
    # in order for mutation analysis to properly work. Randoop-generated tests may report 0 mutants covered
    # during mutation analysis due to issues with test detection, static state handling, or instrumentation.
    # This script modifies the tests to run with the EvoSuite runner, which ensures proper isolation and compatibility
    # for accurate mutant coverage.
    if [ "$SUBJECT_PROGRAM" == "hamcrest-core-1.3" ]; then
      PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
      if [ -z "$PYTHON_EXECUTABLE" ]; then
        echo "Error: Python is not installed." >&2
        exit 1
      fi
      "$PYTHON_EXECUTABLE" "$SCRIPT_DIR"/update_hamcrest_tests.py "$TEST_DIRECTORY"
    fi

    echo
    echo "Running tests with mutation analysis..."
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo command:
      echo "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test
    fi
    echo
    "$MAJOR_HOME"/bin/"$ANT" -f "$SCRIPT_DIR"/program-config/"$1"/build.xml -Dbasedir="$SCRIPT_DIR" -Dbindir="$SCRIPT_DIR/build/bin/$FILE_SUFFIX" -Dresultdir="$RESULT_DIR" -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test

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
    row="$FEATURE_NAME,$(basename "$SRC_JAR"),$LOGGED_TIME,0,$instruction_coverage,$branch_coverage,$mutation_score"
    # info.csv contains a record of each pass.
    echo -e "$row" >> "$SCRIPT_DIR"/results/info.csv

    # Copy the test suites to results directory
    echo "Copying test suites to results directory..."
    cp -r "$TEST_DIRECTORY" "$RESULT_DIR"

    if [[ "$REDIRECT" -eq 1 ]]; then
      exec 1>&3 2>&4
      exec 3>&- 4>&-
    fi

    cd "$SCRIPT_DIR"
  done
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
