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
# - `results/info.csv`: statistics about each iteration.
# - `results/`: everything else specific to the most recent iteration.

#------------------------------------------------------------------------------
# Example usage:
#------------------------------------------------------------------------------
#   ./mutation-evosuite.sh -c 1 commons-lang3-3.0
#
#------------------------------------------------------------------------------
# Options (command-line arguments):
#------------------------------------------------------------------------------
# See variable USAGE_STRING below

#------------------------------------------------------------------------------
# Prerequisites:
#------------------------------------------------------------------------------
# See file `mutation-prerequisites.md`.

# Fail this script on errors.
set -e
set -o pipefail

USAGE_STRING="usage: mutation-evosuite.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] [-n num_iterations] TEST-CASE-NAME
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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAJOR_HOME=$(realpath "${SCRIPT_DIR}/build/major/") # Major home directory, for mutation testing
EVOSUITE_JAR=$(realpath "${SCRIPT_DIR}/build/evosuite-1.2.0.jar") # EvoSuite jar file

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
      VERBOSE=1
      ;;
    r )
      REDIRECT=1
      ;;
    t )
      # Total experiment time, mutually exclusive with SECONDS_PER_CLASS
      TOTAL_TIME="$OPTARG"
      ;;
    c )
      # Default seconds per class.
      # The paper runs Randoop/EvoSuite with 4 different time limits:
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

# Name of the subject program.
SUBJECT_PROGRAM="$1"

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
    ["jcommander-1.35"]="/src/main/java"
    ["jdom-1.0"]="/src/"
    ["joda-time-2.3"]="/src/main/java/"
    ["JSAP-2.1"]="/src/java/"
    ["jvc-1.1"]="/src/"
    ["nekomud-r16"]="/src/"
    ["sat4j-core-2.3.5"]="/org.sat4j.core/src/main/java/"
    ["shiro-core-1.2.3"]="/core/src/main/java/"
    ["slf4j-api-1.7.12"]="/slf4j-api/src/main/java/"
    ["pmd-core-5.2.2"]="/pmd-core/src/main/java/"
)
# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$SRC_BASE_DIR${program_src[$SUBJECT_PROGRAM]}

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="build/lib/"
    ["commons-compress-1.8"]="build/lib/"
    ["easymock-3.2"]="build/lib/"
    ["fixsuite-r48"]="build/lib/"
    ["guava-16.0.1"]="build/lib/"
    ["javassist-3.19"]="build/lib/"
    ["jaxen-1.1.6"]="build/lib/"
    ["jdom-1.0"]="build/lib/"
    ["joda-time-2.3"]="build/lib/"
    ["JSAP-2.1"]="build/lib/"
    ["jvc-1.1"]="build/lib/"
    ["nekomud-r16"]="build/lib/"
    ["pmd-core-5.2.2"]="build/lib/"
    ["sat4j-core-2.3.5"]="build/lib/"
    ["shiro-core-1.2.3"]="build/lib/"
)

#===============================================================================
# Subject Program Specific Dependencies
#===============================================================================
setup_build_dir() {
    rm -rf build/lib
    mkdir -p build/lib
}

download_jars() {
    for url in "$@"; do
        wget -P build/lib "$url"
    done
}

copy_jars() {
    for path in "$@"; do
        cp -r "$path" build/lib
    done
}

case "$SUBJECT_PROGRAM" in
    "a4j-1.0b")
        setup_build_dir
        copy_jars \
            "$SRC_BASE_DIR/jars/jox116.jar" \
            "$SRC_BASE_DIR/jars/log4j-1.2.4.jar" \
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
            "https://repo1.maven.org/maven2/cglib/cglib-nodep/2.2.2/cglib-nodep-2.2.2.jar"
        ;;
    
    "fixsuite-r48")
        setup_build_dir
        copy_jars \
            "$SRC_BASE_DIR/lib/jdom.jar" \
            "$SRC_BASE_DIR/lib/log4j-1.2.15.jar" \
            "$SRC_BASE_DIR/lib/slf4j-api-1.5.0.jar" \
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
            "../subject-programs/jaxen-1.1.6.jar" \
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
            "$SRC_BASE_DIR/lib/snip-0.11.jar" \
        ;;
    
    "jvc-1.1")
        setup_build_dir
        copy_jars \
            "$SRC_BASE_DIR/lib/jsp-api-2.1.jar" \
            "$SRC_BASE_DIR/lib/junit-4.13.jar" \
            "$SRC_BASE_DIR/lib/log4j-1.2.15.jar" \
            "$SRC_BASE_DIR/lib/servlet-api-2.5.jar" \
        ;;

    "nekomud-r16")
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
            "$SRC_BASE_DIR/lib/spring.jar" \
        ;;

    "pmd-core-5.2.2")
        setup_build_dir
        copy_jars \
            "$SRC_BASE_DIR/pmd-core/lib/asm-9.7.jar" \
        ;;

    "sat4j-core-2.3.5")
        setup_build_dir
        copy_jars \
            "$SRC_BASE_DIR/lib/commons-beanutils.jar" \
            "$SRC_BASE_DIR/lib/commons-cli.jar" \
            "$SRC_BASE_DIR/lib/commons-logging.jar" \
            "$SRC_BASE_DIR/lib/jchart2d-3.2.2.jar" \
            "$SRC_BASE_DIR/lib/mockito-all-1.9.5.jar" \
        ;;

    "shiro-core-1.2.3")
        setup_build_dir
        download_jars \
            "https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.8.3/commons-beanutils-1.8.3.jar" \
            "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar"
        ;; 

    *)
        setup_build_dir
        ;;
esac

if [[ "$SUBJECT_PROGRAM" == "hamcrest-core-1.3" ]]; then
    CLASSPATH="$SRC_JAR:build/evosuite-standalone-runtime-1.2.0.jar:build/junit-4.12.jar"
else
    CLASSPATH="$SRC_JAR:build/evosuite-standalone-runtime-1.2.0.jar:build/evosuite-tests/:build/junit-4.12.jar:build/hamcrest-core-1.3.jar"
fi

if [[ -n "${project_deps[$SUBJECT_PROGRAM]}" ]]; then
    CLASSPATH="$CLASSPATH:${project_deps[$SUBJECT_PROGRAM]}"
fi

if [[ "$VERBOSE" -eq 1 ]]; then
    echo "JAVA_SRC_DIR: $JAVA_SRC_DIR"
    echo "CLASSPATH: $CLASSPATH"
    echo
fi

#===============================================================================
# Test generator command configuration
#===============================================================================

EVOSUITE_CLASSPATH="$CLASSPATH"
if [[ -n "${project_deps[$SUBJECT_PROGRAM]}" ]]; then
    # Expand .jar files from the directory specified in project_deps[$SUBJECT_PROGRAM]
    EVOSUITE_CLASSPATH+=":$(echo ${project_deps[$SUBJECT_PROGRAM]}*.jar | tr ' ' ':')"
fi

EVOSUITE_COMMAND=(
    "java"
    "-jar" "$EVOSUITE_JAR"
    "-target" "$SRC_JAR"
    "-projectCP" "$EVOSUITE_CLASSPATH:$EVOSUITE_JAR"
    "-Dsearch_budget=$TIME_LIMIT"
    "-Drandom_seed=0"
)

#===============================================================================
# Build System Preparation
#===============================================================================

echo "Modifying build-evosuite.xml and pom.xml for $SUBJECT_PROGRAM..."
./apply-build-patch-evosuite.sh "$SUBJECT_PROGRAM"

# Installs all of the jarfiles in build/lib to maven (used for measuring code coverage).
./generate-mvn-dependencies.sh

cd "$JAVA_SRC_DIR" || exit 1
if git checkout include-major >/dev/null 2>&1; then
    echo "Checked out include-major."
fi
cd - || exit 1

echo "Using EvoSuite to generate tests."
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "Version,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

#===============================================================================
# Test Generation & Execution
#===============================================================================
# Remove old test directories.
rm -rf "$SCRIPT_DIR"/build/evosuite-tests/ && rm -rf "$SCRIPT_DIR"/build/evosuite-report/ && rm -rf "$SCRIPT_DIR"/build/target/

# The value for the -lib command-line option; that is, the classpath.
LIB_ARG="$CLASSPATH"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 "$NUM_LOOP")
do
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    # Evosuite test directory for each iteration.
    TEST_DIRECTORY="$SCRIPT_DIR/build/evosuite-tests/$TIMESTAMP"
    mkdir -p "$TEST_DIRECTORY"

    # Evosuite report directory for each iteration
    REPORT_DIRECTORY="$SCRIPT_DIR/build/evosuite-report/$TIMESTAMP"
    mkdir -p "$REPORT_DIRECTORY"

    # Jacoco directory for each iteration
    COVERAGE_DIRECTORY="$SCRIPT_DIR/build/target/$TIMESTAMP"
    mkdir -p "$COVERAGE_DIRECTORY"
    mkdir -p $COVERAGE_DIRECTORY/coverage-reports
    touch $COVERAGE_DIRECTORY/coverage-reports/jacoco-ut.exec

    # Result directory for each test generation and execution.
    RESULT_DIR="$SCRIPT_DIR/results/$SUBJECT_PROGRAM-EVOSUITE-$TIMESTAMP"
    mkdir -p "$RESULT_DIR"

    # If the REDIRECT flag is set, redirect all output to a log file.
    if [[ "$REDIRECT" -eq 1 ]]; then
        touch mutation_output.txt
        echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
        exec 3>&1 4>&2
        exec 1>>"mutation_output.txt" 2>&1
    fi

    echo "${EVOSUITE_COMMAND[@]}" -Dtest_dir=$TEST_DIRECTORY -Dreport_dir=$REPORT_DIRECTORY
    "${EVOSUITE_COMMAND[@]}" -Dtest_dir=$TEST_DIRECTORY -Dreport_dir=$REPORT_DIRECTORY

    # After Maven installation and EvoSuite execution, we need to remove the ant.jar from the classpath 
    if [[ "$SUBJECT_PROGRAM" == "JSAP-2.1" ]]; then
        rm "build/lib/ant.jar"
    fi

    #===============================================================================
    # Coverage & Mutation Analysis
    #===============================================================================
    echo
    echo "Compiling and mutating subject program..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile
    fi
    echo
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" clean compile

    echo
    echo "Compiling tests..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests
    fi
    echo
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$LIB_ARG" compile.tests

    echo
    echo "Running tests with coverage..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo mvn test jacoco:restore-instrumented-classes jacoco:report -Dmain.source.dir="$JAVA_SRC_DIR"
    fi
    echo
    mvn test jacoco:restore-instrumented-classes jacoco:report -Dmain.source.dir="$JAVA_SRC_DIR" -Dcoverage.dir="$COVERAGE_DIRECTORY"

    mv $COVERAGE_DIRECTORY/jacoco.csv "$RESULT_DIR"/report.csv

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
        echo "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test
    fi
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -lib "$LIB_ARG" mutation.test

    mv results/summary.csv "$RESULT_DIR"

    # Calculate Mutation Score
    mutants_generated=$(awk -F, 'NR==2 {print $1}' "$RESULT_DIR"/summary.csv)
    mutants_killed=$(awk -F, 'NR==2 {print $4}' "$RESULT_DIR"/summary.csv)
    mutation_score=$(echo "scale=4; $mutants_killed / $mutants_generated * 100" | bc)
    mutation_score=$(printf "%.2f" "$mutation_score")

    echo "Instruction Coverage: $instruction_coverage%"
    echo "Branch Coverage: $branch_coverage%"
    echo "Mutation Score: $mutation_score%"

    row="EVOSUITE,$(basename "$SRC_JAR"),$TIME_LIMIT,0,$instruction_coverage%,$branch_coverage%,$mutation_score%"
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
        "build/pom.xml.bak"
        "results/covMap.csv"
        "results/details.csv"
        "results/preprocessing.ser"
        "results/testMap.csv"
    )
    mv "${FILES_TO_MOVE[@]}" "$RESULT_DIR"
done

#===============================================================================
# Build System Cleanup
#===============================================================================

echo

echo "Restoring build-evosuite.xml and pom.xml"
./apply-build-patch-evosuite.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd "$JAVA_SRC_DIR"; git checkout main 1>/dev/null)
