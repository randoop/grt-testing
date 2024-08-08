#!/bin/bash

# This script does mutation testing with Randoop-generated test suites. Different
# test suites can be generated with Bloodhound, Orienteering, neither (baseline), or both.
# Mutation testing is used on projects provided in table 2 of the GRT paper.

# This script will create Randoop's test suites in a "build/test*" subdirectory. 
# Compiled tests and code will be stored in the "build/bin" subdirectory.
# The script will generate various mutants of the source project using Major and run these tests on those mutants.

# Finally, each experiment can run a given amount of times and a given amount of seconds per class. 
# Various statistics of each iteration will be logged to a file "results/info.txt".
# All other files logged to the "results" subdirectory are specific to the most recent iteration of the experiment. 
# See "reproinstructions.txt" for more instructions on how to run this script.

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

# Link to the major directory
MAJOR_HOME=$(realpath "build/major/")

# Link to current directory
CURR_DIR=$(realpath "$(pwd)")

# Link to the randoop jar
RANDOOP_JAR=$(realpath "build/randoop-all-4.3.3.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound
JACOCO_JAR=$(realpath "build/jacocoagent.jar")

# The paper runs Randoop on 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class
SECONDS_CLASS="2"

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=2

# Link to src jar
SRC_JAR=$(realpath "../tests/$1")

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR="$2"

# Number of classes in given jar file
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Directory that stores compiled versions of Randoop
RANDOOP_VERSIONS_DIR=$(realpath "$SCRIPTDIR/../RandoopVersions")

# Variable that stores command line inputs common among all commands
RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

echo "Using Randoop to generate tests"
echo

# Output file for runtime information 
rm results/info.txt
touch results/info.txt

JAR_DIR="$3"
CLASSPATH=$(echo $JAR_DIR/*.jar | tr ' ' ':')

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
     for j in $(seq 1 $VERSIONS)
     do
         rm -rf "$CURR_DIR"/build/test*
         #The compiled randoop versions in the RANDOOP_VERSIONS_DIR are compiled with the relevant options enabled
         if [ "$j" -eq 1 ]; then
             RANDOOP_VERSION="BLOODHOUND"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testBloodhound"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY" > output-bloodhound.log 2>&1


         elif [ "$j" -eq 2 ]; then
             RANDOOP_VERSION="ORIENTEERING"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testOrienteering"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --input-selection=ORIENTEERING --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 3 ]; then
             RANDOOP_VERSION="BLOODHOUND_AND_ORIENTEERING"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testBloodhoundOrienteering"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --input-selection=ORIENTEERING --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 4 ]; then
             RANDOOP_VERSION="DETECTIVE"
             RANDOOP_JAR="$RANDOOP_VERSIONS_DIR"/Detective.jar
             RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testDemandDriven"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 5 ]; then
             RANDOOP_VERSION="GRT_FUZZING"
             RANDOOP_JAR="$RANDOOP_VERSIONS_DIR"/Fuzzing.jar
             RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testGrtFuzzing"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 6 ]; then
             RANDOOP_VERSION="ELEPHANT_BRAIN"
             RANDOOP_JAR="$RANDOOP_VERSIONS_DIR"/Elephant-Brain.jar
             RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR"/build/testElephantBrain
             mkdir "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 7 ]; then
             RANDOOP_VERSION="CONSTANT_MINING"
             RANDOOP_JAR="$RANDOOP_VERSIONS_DIR"/Constant-Mining.jar
             RANDOOP_COMMAND="java -Xbootclasspath/a:$JACOCO_AGENT_JAR -javaagent:$JACOCO_AGENT_JAR -classpath $SRC_JAR:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testDemandDriven"
             mkdir -p "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"


         elif [ "$j" -eq 8 ]; then
             RANDOOP_VERSION="BASELINE"
             echo "Using $RANDOOP_VERSION"
             echo
             TEST_DIRECTORY="$CURR_DIR/build/testBaseline"
             mkdir "$TEST_DIRECTORY"
             $RANDOOP_COMMAND --junit-output-dir="$TEST_DIRECTORY"
         # Add additional configurations here as needed
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
        echo "Run tests with mutation analysis"
        echo "(ant mutation.test)"
        "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -lib "$CLASSPATH" mutation.test

        # info.txt contains a record of each version of summary.csv that existed.
        cat results/summary.csv >> results/info.txt
     done

# Clean up dangling files
mv jacoco.exec major.log mutants.log results

done
