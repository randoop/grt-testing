#!/bin/bash
# This script restores the original build.xml or applies a build.patch if provided.
# Usage: ./script.sh [path_to_directory]
# If no path is supplied, it recovers build.xml to its default state.

# Recover the original build.xml
echo "Restoring scripts/build.xml to its original version..."
cp build-variants/build.xml build.xml

# Check if a directory is provided
if [ -n "$1" ]; then
  # Check if build.patch exists in the provided directory
  if [ -f "$1/build.patch" ]; then
    echo "build.patch found in $1. Applying patch to build.xml..."
    patch build.xml < "$1/build.patch"
  else
    echo "No build.patch found in $1."
  fi
else
  echo "No directory provided. build.xml has been restored to its original version."
fi