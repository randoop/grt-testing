#!/bin/bash

#===============================================================================
# Overview
#===============================================================================

# For documentation of how to run this script, see file `mutation-repro.md`.
#
# This script:
#  * Generates test suites using EvoSuite.
#  * Computes mutation score (mutants are generated using Major via ant).
#  * Computes code coverage (using Jacoco via Maven).
#
# Each experiment can run multiple times, with a configurable time (in
# seconds per class or total time).
#
# Directories and files:
# - `evosuite-tests/`: generated test suites, including their compiled versions.
# - `build/bin`: Compiled tests and code.
# - 'libs/': All the dependencies Maven needs for performing code coverage.
# - 'target/': Compiled subject program code and compiled tests for Jacoco (code coverage).
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

USAGE_STRING="usage: mutation-evosuite.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"

if [ $# -eq 0 ]; then
    echo "$0: $USAGE_STRING"
    exit 1
fi

#===============================================================================
# Environment Setup
#===============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAJOR_HOME=$(realpath "build/major/") # Major home directory, for mutation testing
CURR_DIR=$(realpath "$(pwd)")
EVOSUITE_JAR=$(realpath "build/evosuite-1.2.0.jar")

#===============================================================================
# Argument Parsing & Experiment Configuration
#===============================================================================
SECONDS_CLASS="2"      # Default seconds per class.
                       # The paper runs the test generator with 4 different time limits:
                       # 2 s/class, 10 s/class, 30 s/class, and 60 s/class.

TOTAL_TIME=""          # Total experiment time, mutually exclusive with SECONDS_CLASS
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

# Initialize variables
TOTAL_TIME=""
SECONDS_CLASS=""

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

# Map test case to their respective source
declare -A project_src=(
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
JAVA_SRC_DIR=$SRC_BASE_DIR${project_src[$SUBJECT_PROGRAM]}

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
    ["fixsuite-r48"]="$SRC_BASE_DIR/lib/"
    ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
    ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
    ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
    ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

# Link to dependencies
CLASSPATH=${project_deps[$SUBJECT_PROGRAM]}

#===============================================================================
# Subject Program Specific Dependencies
#===============================================================================

# Add the src jarfile to the dependency list.
JAR_PATHS="$SRC_JAR"

# Ensure that `hamcrest-core-1.3.jar` is not included multiple times in the dependencies
# as it is required for running EvoSuite-generated tests.
# 
# Note: The subject program's JAR file is always added to the `JAR_PATHS` variable
# (as mentioned above), so this prevents redundant inclusion of the same dependency.
if [[ "$SUBJECT_PROGRAM" == "hamcrest-core-1.3" ]]; then
    JAR_PATHS="$JAR_PATHS:build/evosuite-standalone-runtime-1.2.0.jar:build/junit-4.12.jar"
else
    JAR_PATHS="$JAR_PATHS:build/evosuite-standalone-runtime-1.2.0.jar:evosuite-tests/:build/junit-4.12.jar:build/hamcrest-core-1.3.jar"
fi

# For easymock-3.2, we download some additional external dependencies for evosuite test and source code compilation
if [[ "$SUBJECT_PROGRAM" == "easymock-3.2" ]]; then
    wget -P build/ https://repo1.maven.org/maven2/com/google/dexmaker/dexmaker/1.0/dexmaker-1.0.jar
    wget -P build/ https://repo1.maven.org/maven2/org/objenesis/objenesis/1.3/objenesis-1.3.jar
    wget -P build/ https://repo1.maven.org/maven2/cglib/cglib-nodep/2.2.2/cglib-nodep-2.2.2.jar
    JAR_PATHS="$JAR_PATHS:build/dexmaker-1.0.jar:build/objenesis-1.3.jar:build/cglib-nodep-2.2.2.jar"
fi

# For pmd-core-5.2.2, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "pmd-core-5.2.2" ]]; then
    JAR_PATHS="$JAR_PATHS:../subject-programs/src/pmd-core-5.2.2/pmd-core/lib/asm-9.7.jar"
fi

# For JSAP-2.1, add 3 external dependencies.
if [[ "$SUBJECT_PROGRAM" == "JSAP-2.1" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/com/thoughtworks/xstream/xstream/1.4.21/xstream-1.4.21.jar"
    SPECIFIC_JAR_DIR="$CURR_DIR/../subject-programs/src/JSAP-2.1/lib"
    JAR_PATHS="$JAR_PATHS:build/xstream-1.4.21.jar:$SPECIFIC_JAR_DIR/rundoc-0.11.jar:$SPECIFIC_JAR_DIR/snip-0.11.jar:$SPECIFIC_JAR_DIR/ant.jar"
fi

# For commons-compress-1.8, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "commons-compress-1.8" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/org/tukaani/xz/1.5/xz-1.5.jar"
    JAR_PATHS="$JAR_PATHS:build/xz-1.5.jar"
fi

# For guava-16.0.1, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "guava-16.0.1" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar"
    JAR_PATHS="$JAR_PATHS:build/jsr305-3.0.2.jar"
fi

# For javassist-3.19, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "javassist-3.19" ]]; then
    wget -P build/ "https://maven.jahia.org/maven2/com/sun/tools/1.5.0/tools-1.5.0.jar"
    JAR_PATHS="$JAR_PATHS:build/tools-1.5.0.jar"
fi

# For jaxen-1.1.6, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "jaxen-1.1.6" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/dom4j/dom4j/1.6.1/dom4j-1.6.1.jar"
    wget -P build/ "https://repo1.maven.org/maven2/jdom/jdom/1.0/jdom-1.0.jar"
    wget -P build/ "https://repo1.maven.org/maven2/xml-apis/xml-apis/1.3.02/xml-apis-1.3.02.jar"
    wget -P build/ "https://repo1.maven.org/maven2/xerces/xercesImpl/2.6.2/xercesImpl-2.6.2.jar"
    wget -P build/ "https://repo1.maven.org/maven2/xom/xom/1.0/xom-1.0.jar"
    JAR_PATHS="$JAR_PATHS:build/dom4j-1.6.1.jar:build/jdom-1.0.jar:build/xml-apis-1.3.02.jar:build/xercesImpl-2.6.2.jar:build/xom-1.0.jar"
fi

# For joda-time-2.3, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "joda-time-2.3" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/org/joda/joda-convert/1.2/joda-convert-1.2.jar"
    JAR_PATHS="$JAR_PATHS:build/joda-convert-1.2.jar"
fi

# For shiro-core-1.2.3, add an external dependency.
if [[ "$SUBJECT_PROGRAM" == "shiro-core-1.2.3" ]]; then
    wget -P build/ "https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.8.3/commons-beanutils-1.8.3.jar"
    JAR_PATHS="$JAR_PATHS:build/commons-beanutils-1.8.3.jar"
fi

# For nekomud-r16 and fixsuite-r48, exclude slf4j-log4j12-1.5.*.jar from the dependency list. Including them
# causes a static logger binder error when running with Major. Otherwise, include any other dependency defined in 
# the CLASSPATH variable
for jar in $CLASSPATH/*.jar; do
    if [ -f "$jar" ]; then  # Check if the file exists
        # If the current file is log4j-1.2.15.jar, skip it
        if [[ "$SUBJECT_PROGRAM" == "nekomud-r16" && "$(basename "$jar")" == "slf4j-log4j12-1.5.2.jar" ]]; then
            continue  # Skip this JAR
        fi
        if [[ "$SUBJECT_PROGRAM" == "fixsuite-r48" && "$(basename "$jar")" == "slf4j-log4j12-1.5.0.jar" ]]; then
            continue  # Skip this JAR
        fi
        # Append the jar to the path
        JAR_PATHS="$JAR_PATHS:$jar"
    fi
done

rm -rf libs && mkdir -p libs
# Loop through the JAR_PATHS, splitting by colon and handling each path correctly. We add these jarfiles
# to libs/ because we will eventually install these jarfiles to the local Maven repository.
OLDIFS=$IFS
IFS=":" 
for path in $JAR_PATHS; do
    if [ -d "$path" ]; then
        find "$path" -type f -name "*.jar" -exec cp {} libs/ \;
    elif [ -f "$path" ]; then
        cp "$path" libs/
    else
        echo "Warning: $path is not a valid file or directory"
    fi
done
IFS=$OLDIFS

# For some reason, when tools-1.5.0.jar is included on the classpath for Major, mutation analysis doesn't work.
# However, it is needed for maven, which is why it was added to the libs directory in the previous code block. 
if [[ $SUBJECT_PROGRAM == "javassist-3.19" ]]; then
    # Exclude build/tools-1.5.0.jar from JAR_PATHS for javassist-3.19
    JAR_PATHS=$(echo $JAR_PATHS | sed 's|build/tools-1.5.0.jar:||g' | sed 's|:build/tools-1.5.0.jar||g')
fi

LIB_ARG="-lib $JAR_PATHS"

if [[ "$VERBOSE" -eq 1 ]]; then
    echo "JAVA_SRC_DIR: $JAVA_SRC_DIR"
    echo "CLASSPATH: $CLASSPATH"
    echo "JAR_PATHS: $JAR_PATHS"
    echo
fi

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running the test generator.
if [[ -n "$TOTAL_TIME" ]]; then
    TIME_LIMIT=$(( TOTAL_TIME / NUM_CLASSES ))
elif [[ -n "$SECONDS_CLASS" ]]; then
    TIME_LIMIT=$SECONDS_CLASS
else
    TIME_LIMIT=2
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

#===============================================================================
# Test generator command configuration
#===============================================================================

# - Installs Jacoco 0.8.0 runtime for measuring code coverage
# - Installs EvoSuite standalone runtime to maven for running tests 
mvn install:install-file -Dfile="build/org.jacoco.agent-0.8.0-runtime.jar" -DgroupId="org.jacoco" -DartifactId="org.jacoco.agent" -Dversion="0.8.0" -Dclassifier="runtime" -Dpackaging=jar
mvn install:install-file -Dfile="build/evosuite-standalone-runtime-1.2.0.jar" -DgroupId="org.evosuite" -DartifactId="evosuite-standalone-runtime" -Dversion="1.2.0" -Dpackaging=jar 

rm -rf evosuite-tests && mkdir -p evosuite-tests && rm -rf evosuite-report && mkdir -p evosuite-report
rm -rf target && mkdir -p target
mkdir -p target/coverage-reports
touch target/coverage-reports/jacoco-ut.exec

EVOSUITE_COMMAND=(
    "java"
    "-jar" "$EVOSUITE_JAR"
    "-target" "$SRC_JAR"
    "-projectCP" "$JAR_PATHS:$EVOSUITE_JAR"
    "-Dsearch_budget=$TIME_LIMIT"
    "-Drandom_seed=0"
)

#===============================================================================
# Build System Preparation
#===============================================================================

echo "Modifying build-evosuite.xml and pom.xml for $SUBJECT_PROGRAM..."
./apply-build-patch.sh _ $SUBJECT_PROGRAM

# Installs all of the jarfiles in libs/ to maven (used for measuring code coverage)
./generate-mvn-dependencies.sh

(
    cd "$JAVA_SRC_DIR" || exit 1
    if git rev-parse --verify include-major >/dev/null 2>&1; then
        echo "Checking out include-major..."
        git checkout include-major
    fi
)

echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "GenerationType,FileName,TimeLimit,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

#===============================================================================
# Test Generation & Execution
#===============================================================================

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    # Check if output needs to be redirected for this loop
    if [[ "$REDIRECT" -eq 1 ]]; then
        touch mutation_output.txt
        echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
        exec 3>&1 4>&2
        exec 1>>"mutation_output.txt" 2>&1
    fi

    echo "Using EvoSuite"
    echo
    TEST_DIRECTORY="$CURR_DIR/evosuite-tests/"

    "${EVOSUITE_COMMAND[@]}"

    # We can't have two ant.jar's on our classpath when performing mutation analysis. This code gets rid of ant.jar
    # on the classpath for JSAP-2.1 (should be the last dependency in LIB_ARG).
    if [[ "$SUBJECT_PROGRAM" == "JSAP-2.1" ]]; then
        echo "Removing ant.jar from -lib option"
        LIB_ARG=$(echo "$LIB_ARG" | sed 's/\([^:]*\)[^:]*$/:/' )
    fi

        #===============================================================================
        # Coverage & Mutation Analysis
        #===============================================================================

    RESULT_DIR="results/$(date +%Y%m%d-%H%M%S)-$SUBJECT_PROGRAM-evosuite"
    mkdir -p "$RESULT_DIR"

    echo
    echo "Compiling and mutating project..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile
    fi
    echo
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile

    echo
    echo "Compiling tests..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests
    fi
    echo
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests

    mv major.log build/major.log 
    mv mutants.log build/mutants.log
    mv suppression.log build/suppression.log

    echo
    echo "Running tests with mutation analysis..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "$MAJOR_HOME"/bin/"$ANT" -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test
    fi
    echo "$MAJOR_HOME"/bin/"$ANT" -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test
    "$MAJOR_HOME"/bin/ant -buildfile build-evosuite.xml -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test

    # Calculate Mutation Score
    mutants_generated=$(awk -F, 'NR==2 {print $1}' results/summary.csv)
    mutants_killed=$(awk -F, 'NR==2 {print $4}' results/summary.csv)
    mutation_score=$(echo "scale=4; $mutants_killed / $mutants_generated * 100" | bc)
    mutation_score=$(printf "%.2f" "$mutation_score")

    echo
    echo "Running tests with coverage..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo command:
        echo "mvn clean test -Dmain.source.dir="$JAVA_SRC_DIR""
    fi
    echo
    mvn test jacoco:restore-instrumented-classes jacoco:report -Dmain.source.dir="$JAVA_SRC_DIR"

    # Calculate Instruction Coverage
    inst_missed=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' target/jacoco.csv)
    inst_covered=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' target/jacoco.csv)
    instruction_coverage=$(echo "scale=4; $inst_covered / ($inst_missed + $inst_covered) * 100" | bc)
    instruction_coverage=$(printf "%.2f" "$instruction_coverage")

    # Calculate Branch Coverage
    branch_missed=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' target/jacoco.csv)
    branch_covered=$(awk -F, 'NR>1 {sum+=$7} END {print sum}' target/jacoco.csv)
    branch_coverage=$(echo "scale=4; $branch_covered / ($branch_missed + $branch_covered) * 100" | bc)
    branch_coverage=$(printf "%.2f" "$branch_coverage")

    mv target/jacoco.csv "$RESULT_DIR"

    echo "Instruction Coverage: $instruction_coverage%"
    echo "Branch Coverage: $branch_coverage%"
    echo "Mutation Score: $mutation_score%"

    mv results/summary.csv "$RESULT_DIR"

    row="EVOSUITE,$(basename "$SRC_JAR"),$TIME_LIMIT,$instruction_coverage%,$branch_coverage%,$mutation_score%"
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
    set +e
    # Move all output files into the results/ directory.
    # `suppression.log` may be in one of two locations depending on if using include-major branch.
    mv "$JAVA_SRC_DIR"/suppression.log "$RESULT_DIR" 2>/dev/null
    mv build/suppression.log "$RESULT_DIR" 2>/dev/null
    mv build/major.log build/mutants.log "$RESULT_DIR"
    (cd results; mv covMap.csv details.csv testMap.csv preprocessing.ser ../"$RESULT_DIR")
    set -e
done

#===============================================================================
# Build System Cleanup
#===============================================================================

echo
echo "Restoring build-evosuite.xml"
# restore build.xml and build-evosuite.xml
./apply-build-patch.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd "$JAVA_SRC_DIR"; git checkout main 1>/dev/null)
