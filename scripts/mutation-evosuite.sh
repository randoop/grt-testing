#!/bin/bash

# For documentation of how to run this script, see file `reproinstructions.txt`.

# This script does mutation testing with Evosuite-generated test suites. 

# This script will create Evosuite's test suites in a "evosuite-tests" subdirectory.
# Compiled tests and code will be stored in the "build/bin" subdirectory.
# The script will generate various mutants of the source project using Major and run these tests on those mutants.

# Finally, each experiment can run a given amount of times and a given amount of seconds per class.
# Various statistics of each iteration will be logged to a file "results/info.csv".
# All other files logged to the "results" subdirectory are specific to the most recent iteration of the experiment.

# Fail this script on errors.
set -e
set -o pipefail

if [ $# -eq 0 ]; then
    echo $0: "usage: mutation-evosuite.sh [-vr] <test case name>"
    exit 1
fi

# Check for Java 8
JAVA_VERSION=$(java -version 2>&1 | awk -F'[._"]' 'NR==1{print ($2 == "version" && $3 < 9) ? $4 : $3}')
if [ "$JAVA_VERSION" -ne 8 ]; then
    echo "Requires Java 8. Please use Java 8 to proceed."
    exit 1
fi

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Link to the major directory
MAJOR_HOME=$(realpath "build/major/")

# Link to current directory
CURR_DIR=$(realpath "$(pwd)")

# Link to Evosuite jar file.
EVOSUITE_JAR=$(realpath "build/evosuite-1.2.0.jar")

# Link to jacoco cli jar. This is necessary for coverage report generation.
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")

# The paper runs Randoop with 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class.
SECONDS_CLASS=""

# Total time to run the experiment. Mutually exclusive with SECONDS_CLASS.
TOTAL_TIME=""

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=1

# Verbose option
VERBOSE=0

# Redirect output to mutation_output.txt
REDIRECT=0

# Enforce that mutually exclusive options are not bundled together
for arg in "$@"; do
  if [[ "$arg" =~ ^-.*[tc].*[tc] ]]; then
    echo "Options -t and -c cannot be used together in any form (e.g., -tc or -ct)."
    exit 1
  fi
done

# Parse command-line arguments
while getopts ":hvrt:c:" opt; do
  case ${opt} in
    h )
      echo "Usage: mutation-evosuite.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
      exit 0
      ;;
    v )
      VERBOSE=1
      ;;
    r )
      REDIRECT=1
      ;;
    t )
      TOTAL_TIME="$OPTARG"
      ;;
    c )
      SECONDS_CLASS="$OPTARG"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: mutation-evosuite.sh [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      echo "Usage: mutation-evosuite.sh [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

# Name of test case
SRC_JAR_NAME="$1"

# Name of ant file to use
ANT="ant"

# Use alternative ant file if replacecall is being used for specific projects
case "$SRC_JAR_NAME" in
    "ClassViewer-5.0.5b" | "jcommander-1.35" | "fixsuite-r48")
        ANT="ant.m"
        ;;
esac

echo "Running mutation test on $1"
echo

# Link to the base directory of the source code
SRC_BASE_DIR="$(realpath "$SCRIPTDIR/../subject-programs/src/$SRC_JAR_NAME")"

# Link to src jar
SRC_JAR=$(realpath "$SCRIPTDIR/../subject-programs/$SRC_JAR_NAME.jar")

# Map test case to their respective source
declare -A project_src=(
    ["a4j-1.0b"]="/src/"
    ["asm-5.0.1"]="/src/"
    ["bcel-5.2"]="/src/"
    ["commons-codec-1.9"]="/src/main/java/"
    ["commons-cli-1.2"]="/src/java/"
    ["commons-collections4-4.0"]="/src/main/java/"
    ["commons-lang3-3.0"]="/src/main/java/"
    ["commons-math3-3.2"]="/src/main/java/"
    ["commons-primitives-1.0"]="/src/java/"
    ["dcParseArgs-10.2008"]="/src/"
    ["easymock-3.2"]="/easymock/src/main/java/"
    ["javassist-3.19"]="/src/main/"
    ["jdom-1.0"]="/src/"
    ["JSAP-2.1"]="/src/java/"
    ["jvc-1.1"]="/src/"
    ["nekomud-r16"]="/src/"
    ["shiro-core-1.2.3"]="/core/"
    ["slf4j-api-1.7.12"]="/slf4j-api/src/main/java/"
)

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
    ["fixsuite-r48"]="$SRC_BASE_DIR/lib/jdom.jar:$SRC_BASE_DIR/lib/log4j-1.2.15.jar:$SRC_BASE_DIR/lib/slf4j-api-1.5.0.jar:$SRC_BASE_DIR/lib/slf4j-log4j12-1.5.0.jar"
    ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
    ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
    ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
    ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$SRC_BASE_DIR${project_src[$SRC_JAR_NAME]}

# Link to dependencies
CLASSPATH=${project_deps[$SRC_JAR_NAME]}

# Ensure the directory contains the JAR files
JAR_PATHS="build/evosuite-standalone-runtime-1.2.0.jar:evosuite-tests/:build/junit-4.12.jar:build/hamcrest-core-1.3.jar"
JAR_PATHS="$JAR_PATHS:$SRC_JAR"

if [[ "$SRC_JAR_NAME" == "easymock-3.2" ]]; then
    # Download the 3 necessary JAR files using wget
    wget -P build/ https://repo1.maven.org/maven2/com/google/dexmaker/dexmaker/1.0/dexmaker-1.0.jar
    wget -P build/ https://repo1.maven.org/maven2/org/objenesis/objenesis/1.3/objenesis-1.3.jar
    wget -P build/ https://repo1.maven.org/maven2/cglib/cglib-nodep/2.2.2/cglib-nodep-2.2.2.jar
    
    # Add the downloaded JAR files to JAR_PATHS
    JAR_PATHS="$JAR_PATHS:build/dexmaker-1.0.jar:build/objenesis-1.3.jar:build/cglib-nodep-2.2.2.jar"
fi

if [[ "$SRC_JAR_NAME" == "JSAP-2.1" ]]; then
    # Download the 3 necessary JAR files using wget
    wget -P build/ "https://repo1.maven.org/maven2/com/thoughtworks/xstream/xstream/1.4.21/xstream-1.4.21.jar"
    SPECIFIC_JAR_DIR="$CURR_DIR/../subject-programs/src/JSAP-2.1/lib"
    
    # Add the downloaded JAR files to JAR_PATHS
    JAR_PATHS="$JAR_PATHS:build/xstream-1.4.21.jar:$SPECIFIC_JAR_DIR/rundoc-0.11.jar:$SPECIFIC_JAR_DIR/snip-0.11.jar:$SPECIFIC_JAR_DIR/ant.jar"
fi

# Loop through the JAR files in the specified directory
for jar in $CLASSPATH/*.jar; do
    if [ -f "$jar" ]; then  # Check if the file exists
        JAR_PATHS="$JAR_PATHS:$jar"  # Append the jar to the path
    fi
done

rm -rf libs && mkdir -p libs
# Loop through the JAR_PATHS, splitting by colon and handling each path correctly
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

./generate-mvn-dependencies.sh

# use junit 4.13 if using easymock-3.2
if [[ "$SRC_JAR_NAME" == "easymock-3.2" ]]; then
    sed -i 's/<junit.version>4.12<\/junit.version>/<junit.version>4.13<\/junit.version>/' pom.xml
fi

LIB_ARG=""
if [[ $JAR_PATHS ]]; then
    LIB_ARG="-lib $JAR_PATHS"
fi

if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Source dir: $JAVA_SRC_DIR"
    echo "Dependency dir: $CLASSPATH"
    echo
fi

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop.
if [[ -n "$TOTAL_TIME" ]]; then
    TIME_LIMIT=$(( TOTAL_TIME / NUM_CLASSES ))
elif [[ -n "$SECONDS_CLASS" ]]; then
    TIME_LIMIT=$SECONDS_CLASS
else
    TIME_LIMIT=2
fi

echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

rm -rf evosuite-tests && mkdir -p evosuite-tests && rm -rf evosuite-report && mkdir -p evosuite-report

# Construct the command without a colon after JAR_PATHS
EVOSUITE_COMMAND="java -jar $EVOSUITE_JAR -target $SRC_JAR -projectCP $JAR_PATHS:$EVOSUITE_JAR -Dsearch_budget=$TIME_LIMIT"
EVOSUITE_COMMAND=(
    "java"
    "-jar" "$EVOSUITE_JAR"
    "-target" "$SRC_JAR"
    "-projectCP" "$JAR_PATHS:$EVOSUITE_JAR"
    "-Dsearch_budget=$TIME_LIMIT"
)
if [ "$SRC_JAR_NAME" == "JSAP-2.1" ]; then
    EVOSUITE_COMMAND+=("-Dsandbox=false")
fi

echo "Modifying build-evosuite.xml for $SRC_JAR_NAME..."
./diff-patch.sh _ $SRC_JAR_NAME

echo "Check out include-major branch, if present..."
# ignore error if branch doesn't exist, will stay on main branch
(cd  $JAVA_SRC_DIR; git checkout include-major 2>/dev/null) || true
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "GenerationType,FileName,TimeLimit,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

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

    echo "Using Evosuite"
    echo
    TEST_DIRECTORY="$CURR_DIR/evosuite-tests/"

    "${EVOSUITE_COMMAND[@]}"

    if [[ "$SRC_JAR_NAME" == "JSAP-2.1" ]]; then
        echo "Removing ant.jar from -lib option"
        LIB_ARG=$(echo "$LIB_ARG" | sed 's/\([^:]*\)[^:]*$/:/' )
    fi

    RESULT_DIR="results/$(date +%Y%m%d-%H%M%S)-$SRC_JAR_NAME-evosuite"
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
    mvn clean test jacoco:restore-instrumented-classes jacoco:report -Dmain.source.dir="$JAVA_SRC_DIR"

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

    # Restore pom.xml back to original
    cp pom.xml.bak pom.xml && rm pom.xml.bak

    echo "Instruction Coverage: $instruction_coverage%"
    echo "Branch Coverage: $branch_coverage%"
    echo "Mutation Score: $mutation_score%"

    mv results/summary.csv "$RESULT_DIR"

    row="EVOSUITE-BASELINE,$(basename "$SRC_JAR"),$TIME_LIMIT,$instruction_coverage%,$branch_coverage%,$mutation_score%"
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
    # Move all output files into the results directory
    # suppression.log may be in one of two locations depending on if using include-major branch
    mv "$JAVA_SRC_DIR"/suppression.log "$RESULT_DIR" 2>/dev/null
    mv suppression.log "$RESULT_DIR" 2>/dev/null
    mv major.log mutants.log "$RESULT_DIR"
    (cd results; mv covMap.csv details.csv testMap.csv preprocessing.ser ../"$RESULT_DIR")
    set -e
done

echo

echo "Restoring build-evosuite.xml"
# restore build.xml and build-evosuite.xml
./diff-patch.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd  $JAVA_SRC_DIR; git checkout main 1>/dev/null)
