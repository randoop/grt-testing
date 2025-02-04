#!/bin/bash
# This script restores the original build.xml or applies a build.patch if provided.
# Usage: ./script.sh [subject-program]
# If a program name is not supplied, it restores build.xml to its default state.

# Restore the original build.xml before looking for a patch
cp build-variants/build.xml build.xml
cp build-variants/build-evosuite.xml build-evosuite.xml
cp build-variants/pom.xml pom.xml

# If a second argument is provided, apply the patch to build-evosuite.xml
if [ -n "$2" ]; then
  # Check if build.patch exists in 'build-variants/subject-program'
  if [ -f "build-variants/$2/build-evosuite.patch" ]; then
    echo "build-evosuite.patch found in build-variants/$2. Applying patch to build-evosuite.xml..."
    patch build-evosuite.xml < "build-variants/$2/build-evosuite.patch" 1>/dev/null
    rm -f build-evosuite.xml.orig
  else
    echo "No build-evosuite.patch found in build-variants/$2."
    echo "build-evosuite.xml was restored to its original version..."
  fi
  if [ -f "build-variants/$2/pom.patch" ]; then
    echo "pom.patch found in build-variants/$2. Applying patch to pom.xml..."
    patch pom.xml < "build-variants/$2/pom.patch" 1>/dev/null
    rm -f pom.xml.orig
  else
    echo "No pom.patch found in build-variants/$2."
    echo "pom.xml was restored to its original version..."
  fi
# Check if a subject-program is provided
elif [ -n "$1" ]; then
  # Check if build.patch exists in 'build-variants/subject-program'
  if [ -f "build-variants/$1/build.patch" ]; then
    echo "build.patch found in build-variants/$1. Applying patch to build.xml..."
    patch build.xml < "build-variants/$1/build.patch" 1>/dev/null
    rm -f build.xml.orig
  else
    echo "No build.patch found in build-variants/$1."
    echo "build.xml was restored to its original version..."
  fi
else
  echo "No subject-program provided. build.xml and build-evosuite.xml have been restored to its original version."
fi
