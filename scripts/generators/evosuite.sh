#!/usr/bin/env bash
#
# Wrapper script for Evosuite
#
# Environment variables: Must be set by caller script
# * CLASSPATH           : Dependency locations for subject program
# * SRC_JAR             : Source jar for subject program
# * GENERATOR_JAR       : Evosuite jar
# * TIME_LIMIT          : Total time limit for test generation
# * NUM_CLASSES         : Total number of classes in the subject program

# Check whether the ENVIRONMENT variables are set

# CLASSPATH can be ""
if [ -z "$SRC_JAR" ]; then
    echo "Expected SRC_JAR environment variable" >&2
    set -e
fi
if [ -z "$GENERATOR_JAR" ]; then
    echo "Expected GENERATOR_JAR environment variable" >&2
    set -e
fi
if [ -z "$TIME_LIMIT" ]; then
    echo "Expected TIME_LIMIT environment variable" >&2
    set -e
fi
if [ -z "$NUM_CLASSES" ]; then
    echo "Expected NUM_CLASSES environment variable" >&2
    set -e
fi

# Compute the budget per target class; evenly split the time for search and assertions
budget=$(echo "$TIME_LIMIT/2/$NUM_CLASSES" | bc)
budget=$(( $budget < 1 ? 1 : $budget )) # Set budget to 1 if it's less than 1

parse_config() {
    local file=$1
    grep -v "\s*#" "$file" | tr '\n' ' '
}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
add_config=$(parse_config "$SCRIPT_DIR"/evosuite.config)

# target = SRC_JAR, all classes in file
cmd="java -cp $GENERATOR_JAR org.evosuite.EvoSuite \
-target $SRC_JAR \
-projectCP $(echo $CLASSPATH/*.jar | tr ' ' ':'):$SRC_JAR:$GENERATOR_JAR \
-seed 0 \
-Dsearch_budget=$budget \
-Dassertion_timeout=$budget \
$add_config"

# Return this command to the caller
echo "$cmd"
exit 0