#!/bin/bash
# This script restores the original build.xml or applies a build.patch if provided.
# Usage: ./apply-build-patch-randoop.sh [subject-program]
# It restores the original build.xml if no subject-program is provided.

# Restore the original build.xml before looking for a patch
cp program-config/build.xml build.xml

# Check if a subject-program is provided
if [ -n "$1" ]; then
  # Check if build.patch exists in 'program-config/subject-program'
  if [ -f "program-config/$1/build.patch" ]; then
    echo "build.patch found in program-config/$1. Applying patch to build.xml..."
    patch build.xml < "program-config/$1/build.patch" 1>/dev/null
    rm -f build.xml.orig
  else
    echo "No build.patch found in build-variants/$1."
    echo "build.xml was restored to its original version..."
  fi
else
  echo "No subject-program provided. build.xml has been restored to its original version."
fi