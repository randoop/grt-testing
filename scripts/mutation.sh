#!/bin/bash

# This script does mutation testing with Randoop-generated test suites. Different
# test suites can be generated with Bloodhound, Orienteering, neither (baseline), or both.
# Mutation testing is used on projects provided in table 2 of the GRT paper.

# This script will create Randoop's test suites in a "test" subdirectory. 
# Compiled tests and code will be stored in a "bin" subdirectory.
# The script will generate various mutants of the source project using Major and run these tests on those mutants.

# Finally, each experiment can run a given amount of times and a given amount of seconds per class. 
# Each iteration will be logged to a file "info.txt".
# See "reproinstructions.txt" for more instructions on how to run this script.

make

# Link to the major directory
MAJOR_HOME=$(realpath "../major/")

# Link to the randoop jar
RANDOOP_JAR=$(realpath "jarfiles/randoop-all-4.3.2.jar")

# TODO: The following should be command-line arguments.
# Link to src files containing the project (must be Gradle, Maven, or a Make project)
PROJECT_SRC="/mnt/c/Users/varun/Downloads/commons-cli-1.2-src/commons-cli-1.2-src"

# Link to java src files (exclude subdirectory w/ test files)
JAVA_SRC_FILES="/mnt/c/Users/varun/Downloads/commons-cli-1.2-src/commons-cli-1.2-src/src/java"

# Link to jacoco agent jar
JACOCO_JAR=$(realpath "jarfiles/lib/jacocoagent.jar")

# Link to original directory
CURR_DIR=$(realpath "$(pwd)")

# TODO: This is a crazily low value for Randoop.  Is this just temporary, for testing?
# Seconds per class
SECONDS_CLASS="2"

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=2

# TODO: This file is important to the for loop, but not until then.  So put the code about it just above the for loop.
rm info.txt
touch info.txt
rm -rf $PROJECT_SRC/target # Specific to Apache Commons Cli v 1.2 and its pom.xml file -- will have to generalize in the future

echo "Using Randoop to generate tests"
echo
(cd $PROJECT_SRC && "$CURR_DIR"/compile-project.sh)

# TODO: Please put all variables at the top of the file, rather than interspersing them with code.
# TODO: Put any variables that a user might want to set (or that will eventually be set from command-line arguments) at the beginnig of the variables.
PROJECT_SRC="$PROJECT_SRC/target/classes" # Again, specific to Apache Commons Cli v 1.2 and its pom.xml file -- will have to generalize in the future

find $PROJECT_SRC -type f -name "*.class" -printf "%P\n" | sed 's/\//./g' | sed 's/.class$//' > $PROJECT_SRC/myclasses.txt

NUM_CLASSES=$(wc -l < $PROJECT_SRC/myclasses.txt)
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Variable that stores command line inputs common among all commands
CLI_INPUTS="java -Xbootclasspath/a:$JACOCO_JAR -javaagent:$JACOCO_JAR -classpath $PROJECT_SRC:$RANDOOP_JAR randoop.main.Main gentests --classlist=$PROJECT_SRC/myclasses.txt --time-limit=$TIME_LIMIT"

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    rm -rf test*

    # TODO: There should eventually be a command-line argument that chooses among the variants of Ranndoop.

    echo "Using Bloodhound"
    echo
    mkdir testBloodhound
    TEST_DIRECTORY="testBloodhound"
    $CLI_INPUTS --method-selection=BLOODHOUND --junit-output-dir="$PWD/testBloodhound"

    # echo "Using Orienteering"
    # echo
    # mkdir testOrienteering
    # TEST_DIRECTORY="testOrienteering"
    # $CLI_INPUTS --input-selection=ORIENTEERING --junit-output-dir="$PWD/testOrienteering"

    # echo "Using Bloodhound and Orienteering"
    # echo
    # mkdir testBloodhoundOrienteering
    # TEST_DIRECTORY="testBloodhoundOrienteering"
    # $CLI_INPUTS --input-selection=ORIENTEERING --method-selection=BLOODHOUND --junit-output-dir="$PWD/testBloodhoundOrienteering"

    # echo "Using Baseline Randoop"
    # echo
    # mkdir testBaseline
    # TEST_DIRECTORY="testBaseline"
    # $CLI_INPUTS --junit-output-dir="$PWD/testBaseline"

    echo    
    echo "Compiling and mutating project"
    echo "(ant -Dmutator=\"=mml:\$MAJOR_HOME/mml/all.mml.bin\" clean compile)"
    echo
    "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_FILES" clean compile
    
    echo
    echo "Compiling tests"
    echo "(ant compile.tests)"
    echo
    "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_FILES" compile.tests

    echo
    echo "Run tests with mutation analysis"
    echo "(ant mutation.test)"
    "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" mutation.test

    cat summary.csv >> info.txt
   
done
