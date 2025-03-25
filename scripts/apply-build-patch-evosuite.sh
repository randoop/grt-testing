#!/bin/bash
# This script restores the original build-evosuite.xml and pom.xml files
# or applies the corresponding patch files if provided.
# Usage: ./apply-build-patch.sh [subject-program]
# It restores the build-evosuite.xml and pom.xml files if no subject program is provided.

# Restore the original files before looking for a patch
cp program-config/build-evosuite.xml build-evosuite.xml
cp program-config/pom.xml pom.xml

# Check if a subject-program is provided
if [ -n "$1" ]; then
  # Check if build-evosuite.patch exists in 'program-config/subject-program'
  if [ -f "program-config/$1/build-evosuite.patch" ]; then
    echo "build-evosuite.patch found in program-config/$1. Applying patch to build-evosuite.xml..."
    patch build-evosuite.xml < "program-config/$1/build-evosuite.patch" 1>/dev/null
    rm -f build-evosuite.xml.orig
  else
    echo "No build-evosuite.patch found in program-config/$1."
    echo "build-evosuite.xml was restored to its original version..."
  fi
  # Check if pom.patch exists in 'program-config/subject-program'
  if [ -f "program-config/$1/pom.patch" ]; then
    echo "pom.patch found in program-config/$1. Applying patch to pom.xml..."
    patch pom.xml < "program-config/$1/pom.patch" 1>/dev/null
    rm -f pom.xml.orig
  else
    echo "No pom.patch found in program-config/$1."
    echo "pom.xml was restored to its original version..."
  fi
else
  echo "No subject-program provided. build.xml, build-evosuite.xml, and pom.xml have been restored to its original version."
fi
