#!/usr/bin/env bash
#
# Wrapper script for Evosuite
#
# Environment variables: Must be set by caller script
# * CLASSPATH           : Dependency locations for subject program
# * SRC_JAR             : Source jar for subject program
# * GENERATOR_JAR       : Evosuite jar
# * TIME_LIMIT          : Total time limit for test generation

# Check whether the ENVIRONMENT variables are set
# if [ -z "$CLASSPATH" ]; then
#     echo "Expected CLASSPATH environment variable" >&2
#     set -e
# fi
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

# Compute the budget per target class; evenly split the time for search and assertions
# num_classes=$(wc -l < "$D4J_FILE_TARGET_CLASSES")
# budget=$(echo "$D4J_TOTAL_BUDGET/2/$num_classes" | bc)
budget=$TIME_LIMIT

parse_config() {
    local file=$1
    grep -v "\s*#" "$file" | tr '\n' ' '
}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
add_config=$(parse_config "$SCRIPT_DIR"/evosuite.config)

# target = SRC_JAR, all classes in file
# timeout = TIME_LIMIT
cmd="java -cp $GENERATOR_JAR org.evosuite.EvoSuite \
-target $SRC_JAR
-projectCP $CLASSPATH*:$SRC_JAR:$GENERATOR_JAR 
-seed 0 \
-Dsearch_budget=$budget \
-Dassertion_timeout=$budget \
$add_config"

# Return this command to the caller
echo "$cmd"
exit 0