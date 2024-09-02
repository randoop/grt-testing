#!/bin/bash

# For documentation of how to run this script, see file `reproinstructions.txt`.

# This script does mutation testing with Randoop-generated test suites. Different
# test suites can be generated with Bloodhound, Orienteering, neither (baseline), or both.
# Mutation testing is used on projects provided in table 2 of the GRT paper.

# This script will create Randoop's test suites in a "build/test*" subdirectory.
# Compiled tests and code will be stored in the "build/bin" subdirectory.
# The script will generate various mutants of the source project using Major and run these tests on those mutants.

# Finally, each experiment can run a given amount of times and a given amount of seconds per class.
# Various statistics of each iteration will be logged to a file "results/info.csv".
# All other files logged to the "results" subdirectory are specific to the most recent iteration of the experiment.

# Fail this script on errors.
set -e
set -o pipefail

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

# Link to current version randoop jar. Replace with different version if new GRT component is being tested.
# Link to the randoop jar
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound
JACOCO_AGENT_JAR=$(realpath "build/jacocoagent.jar")

# Link to jacoco cli jar. This is necessary for coverage report generation
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")

# The paper runs Randoop on 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class
SECONDS_CLASS="2"

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=1

# Name of test case
SRC_JAR_NAME="$1"

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
    ["commons-collections4-4.0"]="/src/main/java/"
    ["commons-lang3-3.0"]="/src/main/java/"
    ["commons-math3-3.2"]="/src/main/java/"
    ["commons-primitives-1.0"]="/src/java/"
    ["dcParseArgs-10.2008"]="/src/"
    ["javassist-3.19"]="/src/main/"
    ["JSAP-2.1"]="/src/"
    ["nekomud-r16"]="/src/"
    ["shiro-core-1.2.3"]="/core/"
    ["slf4j-api-1.7.12"]="/slf4j-api"
)

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="$JAVA_SRC_DIR/jars/"
    ["nekomud-r16"]="$JAVA_SRC_DIR/lib/"
)

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$SRC_BASE_DIR${project_src[$SRC_JAR_NAME]}

# Link to dependencies
CLASSPATH=$SRC_BASE_DIR${project_deps[$SRC_JAR_NAME]}

echo "Source dir: $JAVA_SRC_DIR"
echo "Dependency dir: $CLASSPATH"

# Number of classes in given jar file
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Random seed for Randoop
RANDOM_SEED=0

# Variable that stores command line inputs common among all commands
RANDOOP_BASE_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=10 --deterministic=false --randomseed=$RANDOM_SEED"

declare -A command_suffix=(
    ["commons-lang3-3.0"]="--omit-classes=^org\.apache\.commons\.lang3\.RandomStringUtils$"
    ["guava-16.0.1"]="--omit-methods=^com\.google\.common\.util\.concurrent\.Uninterruptibles\.takeUninterruptibly\(java\.util\.concurrent\.BlockingQueue\)$"
)

RANDOOP_COMMAND="$RANDOOP_BASE_COMMAND ${command_suffix[$SRC_JAR_NAME]}"


echo "Modifying build.xml for $SRC_JAR_NAME..."
./diff-patch.sh $SRC_JAR_NAME
echo

echo "Check out include-major branch, if present..."
# ignore error if branch doesn't exist, will stay on main branch
(cd  $JAVA_SRC_DIR; git checkout include-major 2>/dev/null) || true
echo

echo "Using Randoop to generate tests"

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopVersion,FileName,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

# The different versions of Randoop to use. Adjust according to the versions you are testing.
RANDOOP_VERSIONS=( "BASELINE" ) # "BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    for RANDOOP_VERSION in "${RANDOOP_VERSIONS[@]}"
    do
        rm -rf "$CURR_DIR"/build/test*
        echo "Using $RANDOOP_VERSION"
        echo
        TEST_DIRECTORY="$CURR_DIR/build/test/$RANDOOP_VERSION"
        mkdir -p "$TEST_DIRECTORY"

        RANDOOP_COMMAND_2="$RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY"

        if [ "$RANDOOP_VERSION" == "BLOODHOUND" ]; then
            $RANDOOP_COMMAND_2 --method-selection=BLOODHOUND

        elif [ "$RANDOOP_VERSION" == "BASELINE" ]; then
            $RANDOOP_COMMAND_2

        elif [ "$RANDOOP_VERSION" == "ORIENTEERING" ]; then
            $RANDOOP_COMMAND_2 --input-selection=ORIENTEERING

        elif [ "$RANDOOP_VERSION" == "BLOODHOUND_AND_ORIENTEERING" ]; then
            $RANDOOP_COMMAND_2 --input-selection=ORIENTEERING --method-selection=BLOODHOUND

        elif [ "$RANDOOP_VERSION" == "DETECTIVE" ]; then
            $RANDOOP_COMMAND_2 --demand-driven=true

        elif [ "$RANDOOP_VERSION" == "GRT_FUZZING" ]; then
            $RANDOOP_COMMAND_2 --grt-fuzzing=true

        elif [ "$RANDOOP_VERSION" == "ELEPHANT_BRAIN" ]; then
            $RANDOOP_COMMAND_2 --elephant-brain=true

        elif [ "$RANDOOP_VERSION" == "CONSTANT_MINING" ]; then
            $RANDOOP_COMMAND_2 --constant-mining=true

        else
            echo "Unknown RANDOOP_VERSION = $RANDOOP_VERSION"
            exit 1
        fi

        RESULT_DIR="results/$(date +%Y%m%d-%H%M%S)-$RANDOOP_VERSION-$SRC_JAR_NAME-Seed-$RANDOM_SEED"
        mkdir -p "$RESULT_DIR"

        echo
        echo "Compiling and mutating project"
        echo '(ant -Dmutator="=mml:'"$MAJOR_HOME"'/mml/all.mml.bin" clean compile)'
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" clean compile

        echo
        echo "Compiling tests"
        echo "(ant compile.tests)"
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" compile.tests

        echo
        echo "Running tests with coverage"
        echo '(ant -Dmutator="=mml:'"$MAJOR_HOME"'/mml/all.mml.bin" clean compile)'
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" test
        mv jacoco.exec results
        java -jar "$JACOCO_CLI_JAR" report "results/jacoco.exec" --classfiles "$SRC_JAR" --sourcefiles "$JAVA_SRC_DIR" --csv results/report.csv

        # Calculate Instruction Coverage
        inst_missed=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' results/report.csv)
        inst_covered=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' results/report.csv)
        instruction_coverage=$(echo "scale=4; $inst_covered / ($inst_missed + $inst_covered) * 100" | bc)
        instruction_coverage=$(printf "%.2f" "$instruction_coverage")

        # Calculate Branch Coverage
        branch_missed=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' results/report.csv)
        branch_covered=$(awk -F, 'NR>1 {sum+=$7} END {print sum}' results/report.csv)
        branch_coverage=$(echo "scale=4; $branch_covered / ($branch_missed + $branch_covered) * 100" | bc)
        branch_coverage=$(printf "%.2f" "$branch_coverage")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"

        mv results/report.csv "$RESULT_DIR"

        echo
        echo "Running tests with mutation analysis"
        echo "(ant mutation.test)"
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -lib "$CLASSPATH" mutation.test

        # Calculate Mutation Score
        mutants_covered=$(awk -F, 'NR==2 {print $3}' results/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' results/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Mutation Score: $mutation_score%"

        mv results/summary.csv "$RESULT_DIR"

        row="$RANDOOP_VERSION,$(basename "$SRC_JAR"),$instruction_coverage%,$branch_coverage%,$mutation_score%"
        # info.csv contains a record of each pass.
        echo -e "$row" >> results/info.csv
    done

    echo "Results will be saved in $RESULT_DIR"
    set +e
    # Move all output files into the results directory
    # suppression.log may be in one of two locations depending on if using include-major branch
    mv "$JAVA_SRC_DIR"/suppression.log "$RESULT_DIR" 2>/dev/null
    mv suppression.log "$RESULT_DIR" 2>/dev/null
    mv major.log mutants.log "$RESULT_DIR"
    (cd results; mv covMap.csv details.csv testMap.csv preprocessing.ser jacoco.exec ../"$RESULT_DIR")
    set -e
done

echo
echo "Restoring build.xml"
# restore build.xml
./diff-patch.sh > /dev/null

echo "Restoring $JAVA_SRC_DIR to main branch"
# switch to main branch (may already be there)
(cd  $JAVA_SRC_DIR; git checkout main 1>/dev/null)
