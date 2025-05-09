#!/usr/bin/env bash
#
# Wrapper script for Evosuite
#
# Environment variables: Must be set by caller script
# * JACOCO_AGENT_JAR    : Jacoco agent jar used for coverage scores
# * RESULT_DIR          : Directory to write jacoco.exec to
# * CLASSPATH           : Dependency locations for subject program
# * SRC_JAR             : Source jar for subject program
# * GENERATOR_JAR       : Evosuite jar
# * TIME_LIMIT          : Total time limit for test generation
# * NUM_CLASSES         : Total number of classes in the subject program

# Check whether the ENVIRONMENT variables are set

if [ -z "$JACOCO_AGENT_JAR" ]; then
    echo "Expected JACOCO_AGENT_JAR environment variable" >&2
    set -e
fi
if [ -z "$RESULT_DIR" ]; then
    echo "Expected RESULT_DIR environment variable" >&2
    set -e
fi
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

if [[ -z $CLASSPATH ]]; then 
    classpath_jars=""
else
    classpath_jars="$(echo "$CLASSPATH"/*.jar | tr ' ' ':'):"
fi

# Compute the budget per target class; evenly split the time for search and assertions
# budget=$(echo "$TIME_LIMIT/2/$NUM_CLASSES" | bc)
# budget=$(( $budget < 1 ? 1 : $budget )) # Set budget to 1 if it's less than 1
budget="$TIME_LIMIT"

parse_config() {
    local file=$1
    grep -v "\s*#" "$file" | tr '\n' ' '
}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
add_config=$(parse_config "$SCRIPT_DIR"/evosuite.config)

# target = SRC_JAR, all classes in file
cmd="java -javaagent:$JACOCO_AGENT_JAR=destfile=$RESULT_DIR/jacoco.exec \
-cp $GENERATOR_JAR org.evosuite.EvoSuite \
-target $SRC_JAR \
-projectCP $classpath_jars$SRC_JAR:$GENERATOR_JAR \
-seed 0 \
-Dsearch_budget=$budget \
-Dassertion_timeout=$budget \
$add_config"

# Return this command to the caller
echo "$cmd"
exit 0
