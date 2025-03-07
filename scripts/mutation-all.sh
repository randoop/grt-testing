#!/bin/bash
# shellcheck disable=SC2086 # MUTATION_ARGS should not be quoted

# This script runs `mutation.sh` on all the subject programs.

# Initialize default values
VERBOSE=0
REDIRECT=0
TOTAL_TIME=""
SECONDS_CLASS=""

# Parse command-line arguments
while getopts ":hvrt:c:" opt; do
  case ${opt} in
    h )
      echo "Usage: mutation-all.sh [-h] [-v] [-r] [-t total_time] [-c time_per_class]"
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

# Enforce that mutually exclusive options are not bundled together
if [[ -n "$TOTAL_TIME" ]] && [[ -n "$SECONDS_CLASS" ]]; then
  echo "Do not use -t and -c together."
  exit 1
fi

# Prepare the arguments for mutation.sh based on flags
MUTATION_ARGS=""
if [[ "$VERBOSE" -eq 1 ]]; then
  MUTATION_ARGS="$MUTATION_ARGS -v"
fi
if [[ "$REDIRECT" -eq 1 ]]; then
  MUTATION_ARGS="$MUTATION_ARGS -r"
fi
if [[ -n "$TOTAL_TIME" ]]; then
  MUTATION_ARGS="$MUTATION_ARGS -t $TOTAL_TIME"
fi
if [[ -n "$SECONDS_CLASS" ]]; then
  MUTATION_ARGS="$MUTATION_ARGS -c $SECONDS_CLASS"
fi

# Run mutation tests with the supplied arguments before the project name
./mutation.sh $MUTATION_ARGS a4j-1.0b
./mutation.sh $MUTATION_ARGS asm-5.0.1
./mutation.sh $MUTATION_ARGS bcel-5.2
./mutation.sh $MUTATION_ARGS ClassViewer-5.0.5b
./mutation.sh $MUTATION_ARGS commons-cli-1.2
./mutation.sh $MUTATION_ARGS commons-codec-1.9
./mutation.sh $MUTATION_ARGS commons-collections4-4.0
./mutation.sh $MUTATION_ARGS commons-compress-1.8
./mutation.sh $MUTATION_ARGS commons-lang3-3.0
./mutation.sh $MUTATION_ARGS commons-math3-3.2
./mutation.sh $MUTATION_ARGS commons-primitives-1.0
./mutation.sh $MUTATION_ARGS dcParseArgs-10.2008
./mutation.sh $MUTATION_ARGS easymock-3.2
./mutation.sh $MUTATION_ARGS fixsuite-r48
./mutation.sh $MUTATION_ARGS guava-16.0.1
./mutation.sh $MUTATION_ARGS hamcrest-core-1.3
./mutation.sh $MUTATION_ARGS javassist-3.19
./mutation.sh $MUTATION_ARGS javax.mail-1.5.1
./mutation.sh $MUTATION_ARGS jaxen-1.1.6
./mutation.sh $MUTATION_ARGS jcommander-1.35
./mutation.sh $MUTATION_ARGS jdom-1.0
./mutation.sh $MUTATION_ARGS joda-time-2.3
./mutation.sh $MUTATION_ARGS JSAP-2.1
./mutation.sh $MUTATION_ARGS jvc-1.1
./mutation.sh $MUTATION_ARGS nekomud-r16
./mutation.sh $MUTATION_ARGS pmd-core-5.2.2
./mutation.sh $MUTATION_ARGS sat4j-core-2.3.5
./mutation.sh $MUTATION_ARGS shiro-core-1.2.3
./mutation.sh $MUTATION_ARGS slf4j-api-1.7.12
./mutation.sh $MUTATION_ARGS tinySQL-2.26
