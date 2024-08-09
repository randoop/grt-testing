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

make

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Link to the major directory
MAJOR_HOME=$(realpath "build/major/")

# Link to current directory
CURR_DIR=$(realpath "$(pwd)")

# Link to the randoop jar
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound
JACOCO_AGENT_JAR=$(realpath "build/jacocoagent.jar")

# Link to jacoco cli jar. This is necessary for coverage report generation
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")

# The paper runs Randoop on 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class
SECONDS_CLASS="2"

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=2

# Link to src jar
SRC_JAR=$(realpath "$SCRIPTDIR/../tests/$1")

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR="$2"

# Number of classes in given jar file
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Variable that stores command line inputs common among all commands
RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

echo "Using Randoop to generate tests"
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopVersion,FileName,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

JAR_DIR="$3"
CLASSPATH="$(echo "$JAR_DIR"/*.jar | tr ' ' ':')"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    rm -rf "$CURR_DIR"/build/test*

    # TODO: There should eventually be a command-line argument that chooses among the variants of Ranndoop.

    echo "Using Bloodhound"
    echo
    TEST_DIRECTORY="$CURR_DIR"/build/testBloodhound
    mkdir "$TEST_DIRECTORY"
    $RANDOOP_COMMAND --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Orienteering"
    # echo
    # TEST_DIRECTORY="$CURR_DIR"/build/testOrienteering
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --input-selection=ORIENTEERING --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Bloodhound and Orienteering"
    # echo
    # TEST_DIRECTORY="$CURR_DIR"/build/testBloodhoundOrienteering
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --input-selection=ORIENTEERING --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Demand Driven"
    # echo
    # TEST_DIRECTORY="$CURR_DIR"/build/testDemandDriven
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --demand-driven=true --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using GRT Fuzzing"
    # echo
    # TEST_DIRECTORY="$CURR_DIR"/build/testGrtFuzzing
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --grt-fuzzing=true --grt-fuzzing-stddev=30.0 --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Elephant Brain"
    # echo
    # TEST_DIRECTORY="$CURR_DIR"/build/testElephantBrain
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --elephant-brain=true --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Baseline Randoop"
    # echo
    # TEST_DIRECTORY="$CURR_DIR/build/testBaseline"
    # mkdir "$TEST_DIRECTORY"
    # $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"

    "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -lib "$CLASSPATH" test >/dev/null 2>&1
    mv jacoco.exec major.log mutants.log suppression.log results
    java -jar "$JACOCO_CLI_JAR" report "results/jacoco.exec" --classfiles "$SRC_JAR" --sourcefiles "$JAVA_SRC_DIR" --csv results/report.csv

    # Calculate Instruction Coverage
    inst_missed=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' results/report.csv)
    inst_covered=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' results/report.csv)
    instruction_coverage=$(echo "scale=4; $inst_covered / ($inst_missed + $inst_covered) * 100" | bc)

    # Calculate Branch Coverage
    branch_missed=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' results/report.csv)
    branch_covered=$(awk -F, 'NR>1 {sum+=$7} END {print sum}' results/report.csv)
    branch_coverage=$(echo "scale=4; $branch_covered / ($branch_missed + $branch_covered) * 100" | bc)

    echo "Instruction Coverage: $instruction_coverage%"
    echo "Branch Coverage: $branch_coverage%"

    echo
    echo "Run tests with mutation analysis"
    echo "(ant mutation.test)"
    "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -lib "$CLASSPATH" mutation.test >/dev/null 2>&1

    # Calculate Mutation Score
    mutants_covered=$(awk -F, 'NR==2 {print $3}' results/summary.csv)
    mutants_killed=$(awk -F, 'NR==2 {print $4}' results/summary.csv)
    mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)

    echo "Mutation Score: $mutation_score%"

    row="$RANDOOP_VERSION,$(basename "$SRC_JAR"),$instruction_coverage%,$branch_coverage%,$mutation_score%"
    # info.csv contains a record of each pass.
    echo -e "$row" >> results/info.csv
done
