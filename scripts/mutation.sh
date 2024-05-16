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

# Link to the major directory
MAJOR_HOME=$(realpath "build/major/")

# Link to current directory
CURR_DIR=$(realpath "$(pwd)")

# Link to the randoop jar
RANDOOP_JAR=$(realpath "/Users/ziheji/Desktop/academic/Research/randoop/build/libs/randoop-all-4.3.2.jar")

# Link to jacoco agent jar. This is necessary for Bloodhound
JACOCO_JAR=$(realpath "build/jacocoagent.jar")

# Link to junit jar. 
JUNIT_JAR=$(realpath "build/major/lib/ant-junit.jar")

# Link to javaparser jar. This is necessary for eliminating methods that fail in isolation.
JAVAPARSER_JAR=$(realpath "build/javaparser-core-3.25.10.jar")

# The paper runs Randoop on 4 different time limits. These are: 2 s/class, 10 s/class, 30 s/class, and 60 s/class
SECONDS_CLASS="1"

# Number of times to run experiments (10 in GRT paper)
NUM_LOOP=1

# Link to src jar
SRC_JAR=$(realpath "$1")

# Link to src files for mutation generation and analysis
JAVA_SRC_DIR=$(realpath "$2")

# Variable containing the directory of any additional jarfiles needed for source compilation
ALT_JARFILES=$(realpath "$3")

# Number of classes in given jar file
NUM_CLASSES=$(jar -tf "$SRC_JAR" | grep -c '.class')

# Time limit for running Randoop
TIME_LIMIT=$((NUM_CLASSES * SECONDS_CLASS))

# Variable that stores command line inputs common among all commands
#CLI_INPUTS="java -Xbootclasspath/a:$JACOCO_JAR -javaagent:$JACOCO_JAR -classpath $SRC_JAR:$ALT_JARFILES/*:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --constant-mining=true --literals-level=ALL --constant_mining_probability=1 --time-limit=$TIME_LIMIT"
CLI_INPUTS="java -Xbootclasspath/a:$JACOCO_JAR -javaagent:$JACOCO_JAR -classpath $SRC_JAR:$ALT_JARFILES/*:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --constant-mining=true --literals-level=ALL --constant_mining_probability=0.3 --log=randooplog.txt --selection-log=selection.txt --time-limit=$TIME_LIMIT"
#CLI_INPUTS="java -Xbootclasspath/a:$JACOCO_JAR -javaagent:$JACOCO_JAR -classpath $SRC_JAR:$ALT_JARFILES/*:$RANDOOP_JAR randoop.main.Main gentests --testjar=$SRC_JAR --time-limit=$TIME_LIMIT"

# Variable that stores any additional arguments to calling Randoop
ADDITIONAL_ARGS="$4"

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

echo "Using Randoop to generate tests"
echo

# Output file for runtime information 
rm results/info.txt
touch results/info.txt

# shellcheck disable=SC2034 # i counts iterations but is not otherwise used.
for i in $(seq 1 $NUM_LOOP)
do
    rm -rf "$CURR_DIR"/build/test*

    # TODO: There should eventually be a command-line argument that chooses among the variants of Ranndoop.

    # echo "Using Bloodhound"
    # echo
    # TEST_DIRECTORY="$CURR_DIR/build/testBloodhound/"
    # mkdir "$TEST_DIRECTORY"
    # $CLI_INPUTS --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Orienteering"
    # echo
    # TEST_DIRECTORY="$CURR_DIR/build/testOrienteering/"
    # mkdir "$TEST_DIRECTORY"
    # $CLI_INPUTS --input-selection=ORIENTEERING --junit-output-dir="$TEST_DIRECTORY"

    # echo "Using Bloodhound and Orienteering"
    # echo
    # TEST_DIRECTORY="$CURR_DIR/build/testBloodhoundOrienteering/"
    # mkdir "$TEST_DIRECTORY"
    # $CLI_INPUTS --input-selection=ORIENTEERING --method-selection=BLOODHOUND --junit-output-dir="$TEST_DIRECTORY"

    echo "Using Baseline Randoop"
    echo
    TEST_DIRECTORY="$CURR_DIR/build/testBaseline/"
    mkdir "$TEST_DIRECTORY"
    $CLI_INPUTS $ADDITIONAL_ARGS --junit-output-dir="$TEST_DIRECTORY"

    javac -cp $JAVAPARSER_JAR MethodExtractor.java

    files=$(find $TEST_DIRECTORY -maxdepth 1 -type f -name "RegressionTest*.java" ! -name "RegressionTest.java")

    for file in $files; do
        base_name=$(basename "$file" .java)
        jarfiles="$SRC_JAR:$RANDOOP_JAR:$JUNIT_JAR"
        if [[ -n $ALT_JARFILES ]]; then
            jarfiles="$jarfiles:$ALT_JARFILES"
        fi
        java -classpath .:$JAVAPARSER_JAR MethodExtractor "$base_name" "$TEST_DIRECTORY" "$jarfiles"
        mv "${base_name}.java" "$TEST_DIRECTORY"
    done

    cp randooplog.txt results/randooplog.txt
    cp selection.txt results/selection.txt
    rm Temp.java Temp.class MethodExtractor.class

    echo    
    echo "Compiling and mutating project"
    echo "(ant -Dmutator=\"=mml:\$MAJOR_HOME/mml/all.mml.bin\" clean compile)"
    echo
    "$MAJOR_HOME"/bin/ant -Dmutator="mml:$MAJOR_HOME/mml/all.mml.bin" -Dsrc="$JAVA_SRC_DIR" -Dalt="$ALT_JARFILES" clean compile
    
    echo
    echo "Compiling tests"
    echo "(ant compile.tests)"
    echo
    "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dsrc="$JAVA_SRC_DIR" -Dalt="$ALT_JARFILES" compile.tests



    echo
    echo "Run tests with mutation analysis"
    echo "(ant mutation.test)"
    "$MAJOR_HOME"/bin/ant -Dtest="$TEST_DIRECTORY" -Dalt="$ALT_JARFILES" mutation.test

    cat results/summary.csv >> results/info.txt

# Clean up dangling files
rm jacoco.exec major.log mutants.log
rm results/summary.csv results/covMap.csv results/testMap.csv results/details.csv results/preprocessing.ser

done
