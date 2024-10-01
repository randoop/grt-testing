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

if [ $# -eq 0 ]; then
    echo $0: "usage: mutation.sh [-vr] <test case name>"
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

# Link to Randoop jar file. Replace with different file if new GRT component is being tested.
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound.
JACOCO_AGENT_JAR=$(realpath "build/jacocoagent.jar")

# Link to jacoco cli jar. This is necessary for coverage report generation.
JACOCO_CLI_JAR=$(realpath "build/jacococli.jar")

# Link to replacecall jar. This is necessary for not calling certain undesired methods,
# such as JOptionPane.showMessageDialog.
REPLACECALL_JAR=$(realpath "build/replacecall-4.3.3.jar")

# Link to replacecall replacements file, which defines the methods to replace.
# REPLACECALL_REPLACEMENTS=$(realpath "replacecall-replacements.txt")

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
      echo "Usage: mutation.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
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
      echo "Usage: mutation.sh [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      echo "Usage: mutation.sh [-v] [-r] [-t total_time] [-c time_per_class] <test case name>"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

# Name of test case
SRC_JAR_NAME="$1"

# Name of ant file to use
ANT="ant"

# If SRC_JAR_NAME is ClassViewer-5.0.5b, use alternative ant file
# if [ "$SRC_JAR_NAME" == "ClassViewer-5.0.5b" ]; then
#    ANT="ant.m"
# fi

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

# Map project names to their respective dependencies
declare -A project_deps=(
    ["a4j-1.0b"]="$SRC_BASE_DIR/jars/"
    ["fixsuite-r48"]="$SRC_BASE_DIR/lib/jdom.jar:$SRC_BASE_DIR/lib/log4j-1.2.15.jar:$SRC_BASE_DIR/lib/slf4j-api-1.5.0.jar:$SRC_BASE_DIR/lib/slf4j-log4j12-1.5.0.jar"
    ["jdom-1.0"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"
    ["JSAP-2.1"]="$MAJOR_HOME/lib/ant:$SRC_BASE_DIR/lib/"  # need to override ant.jar in $SRC_BASE_DIR/lib
    ["jvc-1.1"]="$SRC_BASE_DIR/lib/"
    ["nekomud-r16"]="$SRC_BASE_DIR/lib/"
    ["sat4j-core-2.3.5"]="$SRC_BASE_DIR/lib/"
)
#   ["hamcrest-core-1.3"]="$SRC_BASE_DIR/lib/"  this one needs changes?

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$SRC_BASE_DIR${project_src[$SRC_JAR_NAME]}

# Link to dependencies
CLASSPATH=${project_deps[$SRC_JAR_NAME]}
LIB_ARG=""
if [[ $CLASSPATH ]]; then
    LIB_ARG="-lib $CLASSPATH"
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
    TIME_LIMIT="$TOTAL_TIME"
elif [[ -n "$SECONDS_CLASS" ]]; then
    TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))
else
    TIME_LIMIT=$((NUM_CLASSES * 2))
fi
# TIME_LIMIT=60
echo "TIME_LIMIT: $TIME_LIMIT seconds"
echo

# Random seed for Randoop
RANDOM_SEED=0

# Variable that stores command line inputs common among all commands
# Note that if there is no project_deps entry, this command adds a classpath
# element of '*', but it doesn't seem to matter.
RANDOOP_BASE_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR:$REPLACECALL_JAR -javaagent:$JACOCO_AGENT_JAR -javaagent:$REPLACECALL_JAR -classpath $CLASSPATH*:$SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT --deterministic=false --no-error-revealing-tests=true --randomseed=$RANDOM_SEED"

# NOTE: The following omits are based on BASELINE Randoop, seed 0.
declare -A command_suffix=(
    # Bad inputs generated and caused infinite loops
    ["ClassViewer-5.0.5b"]="--specifications=project-specs/ClassViewer-5.0.5b-specs.json"
    # Bad inputs generated and caused infinite loops
    ["commons-lang3-3.0"]="--specifications=project-specs/commons-lang3-3.0-specs.json"
    # An empty BlockingQueue was generated and used but never filled for take(), led to non-termination
    ["guava-16.0.1"]="--specifications=project-specs/guava-16.0.1-specs.json"
    # Randoop generated bad test sequences for handling webserver lifecycle, don't test them
    # ["javassist-3.19"]="--specifications=project-specs/javassist-3.19-specs.json"
    ["javassist-3.19"]="--omit-methods=^javassist\.tools\.web\.Webserver\.run\(\)$ --omit-methods=^javassist\.tools\.rmi\.AppletServer\.run\(\)$"
    # JDOMAbout cannot be found during test.compile, and the class itself isn't interesting
    ["jdom-1.0"]="--omit-classes=^JDOMAbout$"
    # Bad inputs generated and caused infinite loops
    ["jaxen-1.1.6"]="--specifications=project-specs/jaxen-1.1.6-specs.json"
    # Bad inputs cause exceptions in different threads, directly terminating Randoop
    ["sat4j-core-2.3.5"]="--specifications=project-specs/sat4j-core-2.3.5-specs.json"
)

RANDOOP_COMMAND="$RANDOOP_BASE_COMMAND ${command_suffix[$SRC_JAR_NAME]}"

echo "Modifying build.xml for $SRC_JAR_NAME..."
./diff-patch.sh $SRC_JAR_NAME

echo "Check out include-major branch, if present..."
# ignore error if branch doesn't exist, will stay on main branch
(cd  $JAVA_SRC_DIR; git checkout include-major 2>/dev/null) || true
echo

# Output file for runtime information
mkdir -p results/
if [ ! -f "results/info.csv" ]; then
    touch results/info.csv
    echo -e "RandoopVersion,FileName,TimeLimit,Seed,InstructionCoverage,BranchCoverage,MutationScore" > results/info.csv
fi

# The feature names must not contain whitespace.
ALL_RANDOOP_FEATURES=("BASELINE" "BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")
# The different features of Randoop to use. Adjust according to the features you are testing.
RANDOOP_FEATURES=("BASELINE") #"BLOODHOUND" "ORIENTEERING" "BLOODHOUND_AND_ORIENTEERING" "DETECTIVE" "GRT_FUZZING" "ELEPHANT_BRAIN" "CONSTANT_MINING")

# When ABLATION is set to false, the script tests the Randoop features specified in the RANDOOP_FEATURES array.
# When ABLATION is set to true, each run tests all Randoop features except the one specified in the RANDOOP_FEATURES array.
ABLATION=false

# Ensure the given features are legal.
for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}" ; do
    if [[ ! " ${ALL_RANDOOP_FEATURES[*]} " =~ [[:space:]]${RANDOOP_FEATURE}[[:space:]] ]]; then
        echo "$RANDOOP_FEATURE" is not in "${RANDOOP_FEATURES[@]}"
        exit 2
    fi
done

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    for RANDOOP_FEATURE in "${RANDOOP_FEATURES[@]}"
    do

        # Check if output needs to be redirected for this loop
        if [[ "$REDIRECT" -eq 1 ]]; then
            touch mutation_output.txt
            echo "Redirecting output to $RESULT_DIR/mutation_output.txt..."
            exec 3>&1 4>&2
            exec 1>>"mutation_output.txt" 2>&1
        fi

        FEATURE_NAME=""
        if [[ "$ABLATION" == "true" ]]; then
            FEATURE_NAME="ALL-EXCEPT-$RANDOOP_FEATURE"
        else
            FEATURE_NAME="$RANDOOP_FEATURE"
        fi

        rm -rf "$CURR_DIR"/build/test*
        echo "Using $FEATURE_NAME"
        echo
        TEST_DIRECTORY="$CURR_DIR/build/test/$FEATURE_NAME"
        mkdir -p "$TEST_DIRECTORY"

        RANDOOP_COMMAND_2="$RANDOOP_COMMAND --junit-output-dir=$TEST_DIRECTORY"

        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BLOODHOUND" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --method-selection=BLOODHOUND"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "BASELINE" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BASELINE" && "$ABLATION" == "true" ) ]]; then
            ## There is nothing to do in this case.
            # RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2"
            true
        fi

        if [[ ( "$RANDOOP_FEATURE" == "ORIENTEERING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --input-selection=ORIENTEERING"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "BLOODHOUND_AND_ORIENTEERING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --input-selection=ORIENTEERING --method-selection=BLOODHOUND"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "DETECTIVE" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "DETECTIVE" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --demand-driven=true"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "GRT_FUZZING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "GRT_FUZZING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --grt-fuzzing=true"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "ELEPHANT_BRAIN" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "ELEPHANT_BRAIN" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --elephant-brain=true"
        fi

        if [[ ( "$RANDOOP_FEATURE" == "CONSTANT_MINING" && "$ABLATION" != "true" ) || ( "$RANDOOP_FEATURE" != "CONSTANT_MINING" && "$ABLATION" == "true" ) ]]; then
            RANDOOP_COMMAND_2="$RANDOOP_COMMAND_2 --constant-mining=true"
        fi

        $RANDOOP_COMMAND_2

        RESULT_DIR="results/$(date +%Y%m%d-%H%M%S)-$FEATURE_NAME-$SRC_JAR_NAME-Seed-$RANDOM_SEED"
        mkdir -p "$RESULT_DIR"

        echo
        echo "Compiling and mutating project..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" clean compile

        echo
        echo "Compiling tests..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" compile.tests

        echo
        echo "Running tests with coverage..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" test
        fi
        echo
        "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" "$LIB_ARG" test
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
        echo "Running tests with mutation analysis..."
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo command:
            echo "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test
        fi
        echo
        "$MAJOR_HOME"/bin/"$ANT" -Dtest="$TEST_DIRECTORY" "$LIB_ARG" mutation.test

        # Calculate Mutation Score
        mutants_covered=$(awk -F, 'NR==2 {print $3}' results/summary.csv)
        mutants_killed=$(awk -F, 'NR==2 {print $4}' results/summary.csv)
        mutation_score=$(echo "scale=4; $mutants_killed / $mutants_covered * 100" | bc)
        mutation_score=$(printf "%.2f" "$mutation_score")

        echo "Instruction Coverage: $instruction_coverage%"
        echo "Branch Coverage: $branch_coverage%"
        echo "Mutation Score: $mutation_score%"

        mv results/summary.csv "$RESULT_DIR"

        row="$FEATURE_NAME,$(basename "$SRC_JAR"),$TIME_LIMIT,$RANDOM_SEED,$instruction_coverage%,$branch_coverage%,$mutation_score%"
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
