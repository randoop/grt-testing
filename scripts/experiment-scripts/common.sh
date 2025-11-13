#!/bin/bash

PYTHON_EXECUTABLE=$(command -v python3 2> /dev/null || command -v python 2> /dev/null)
if [ -z "$PYTHON_EXECUTABLE" ]; then
  echo "Error: Python is not installed." >&2
  exit 2
fi

# shellcheck disable=SC2034
SUBJECT_PROGRAMS=(
  "a4j-1.0b"
  "asm-5.0.1"
  "bcel-5.2"
  "ClassViewer-5.0.5b"
  "commons-cli-1.2"
  "commons-codec-1.9"
  "commons-collections4-4.0"
  "commons-compress-1.8"
  "commons-lang3-3.0"
  "commons-math3-3.2"
  "commons-primitives-1.0"
  "dcParseArgs-10.2008"
  "easymock-3.2"
  "fixsuite-r48"
  "guava-16.0.1"
  "hamcrest-core-1.3"
  "javassist-3.19"
  "javax.mail-1.5.1"
  "jaxen-1.1.6"
  "jcommander-1.35"
  "jdom-1.0"
  "joda-time-2.3"
  "JSAP-2.1"
  "jvc-1.1"
  "nekomud-r16"
  "pmd-core-5.2.2"
  "sat4j-core-2.3.5"
  "shiro-core-1.2.3"
  "slf4j-api-1.7.12"
  "tiny-sql-2.26"
)

num_cores() {
  if command -v nproc > /dev/null 2>&1; then
    NPROC=$(nproc)
  elif command -v getconf > /dev/null 2>&1; then
    NPROC=$(getconf _NPROCESSORS_ONLN)
  else
    NPROC=1
  fi
  NUM_CORES=$((NPROC - 4))
  if [ "$NUM_CORES" -lt 1 ]; then NUM_CORES=1; fi
  echo "$NUM_CORES"
}
