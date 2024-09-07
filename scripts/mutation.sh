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

# Link to Randoop jar file. Replace with different file if new GRT component is being tested.
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound.
JACOCO_AGENT_JAR=$(realpath "build/jacocoagent.jar")

# Link to jacoco cli jar. This is necessary for coverage report generation.
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")

# The paper runs Randoop with 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class.
SECONDS_CLASS="2"

# Number of times to run experiments (10 in GRT paper).
NUM_LOOP=2

# Link to src jar.
SRC_JAR=$(realpath "$SCRIPTDIR/../subject-programs/$1")

# Link to src files for mutation generation and analysis.
JAVA_SRC_DIR="$2"

# Number of classes in given jar file.
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop.
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Command line inputs common among all commands.
RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

echo "Using Randoop to generate tests"
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopFeature,FileName,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

JAR_DIR="$3"
CLASSPATH="$(echo "$JAR_DIR"/*.jar | tr ' ' ':')"

# The different features of Randoop to use. Adjust according to the features you are testing.
RANDOOP_FEATURES=("BLOODHOUND" "BASELINE") #"ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}"
    do
        rm -rf "$CURR_DIR"/build/test*
        echo "Using $RANDOOP_FEATURE"
        echo
        TEST_DIRECTORY="$CURR_DIR/build/test/$RANDOOP_FEATURE"
        mkdir -p "$TEST_DIRECTORY"

        RANDOOP_COMMAND_2="$RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY"

        if [ "$RANDOOP_FEATURE" == "BLOODHOUND" ]; then
            $RANDOOP_COMMAND_2 --method-selection=BLOODHOUND

        elif [ "$RANDOOP_FEATURE" == "BASELINE" ]; then
            $RANDOOP_COMMAND_2

        elif [ "$RANDOOP_FEATURE" == "ORIENTEERING" ]; then
            $RANDOOP_COMMAND_2 --input-selection=ORIENTEERING

        elif [ "$RANDOOP_FEATURE" == "BLOODHOUND_AND_ORIENTEERING" ]; then
            $RANDOOP_COMMAND_2 --input-selection=ORIENTEERING --method-selection=BLOODHOUND

        elif [ "$RANDOOP_FEATURE" == "DETECTIVE" ]; then
            $RANDOOP_COMMAND_2 --demand-driven=true

        elif [ "$RANDOOP_FEATURE" == "GRT_FUZZING" ]; then
            $RANDOOP_COMMAND_2 --grt-fuzzing=true

        elif [ "$RANDOOP_FEATURE" == "ELEPHANT_BRAIN" ]; then
            $RANDOOP_COMMAND_2 --elephant-brain=true

        elif [ "$RANDOOP_FEATURE" == "CONSTANT_MINING" ]; then
            $RANDOOP_COMMAND_2 --constant-mining=true

        else
            echo "Unknown RANDOOP_FEATURE = $RANDOOP_FEATURE"
            exit 1
        fi

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

        echo
        echo "Run tests with mutation analysis"
        echo "(ant mutation.test)"
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -lib "$CLASSPATH" mutation.test

        # Calculate Mutation Score
        mutants_covered=$(awk -F, 'NR==2 {print $3}' results/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' results/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Mutation Score: $mutation_score%"

        row="$RANDOOP_FEATURE,$(basename "$SRC_JAR"),$instruction_coverage%,$branch_coverage%,$mutation_score%"
        # info.csv contains a record of each pass.
        echo -e "$row" >> results/info.csv
    done

    # Move all output files into results/ directory.
    mv suppression.log major.log mutants.log results
done
