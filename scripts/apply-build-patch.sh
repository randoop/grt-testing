#!/bin/bash
# This script restores the original build.xml, build-evosuite.xml, and pom.xml files, 
# or applies the corresponding patch files if provided.
# 
# Usage for Randoop (mutation.sh):
#   ./apply-build-patch.sh [subject-program]
#   In this case, only the build.patch file is applied.
# 
# Usage for Evosuite (mutation-evosuite.sh):
#   ./apply-build-patch.sh _ [subject-program]
#   Here, the build-evosuite.patch and pom.patch files are applied.
# 
# If no program name is supplied, the script restores build.xml, build-evosuite.xml, and pom.xml 
# to their default state.

# Restore the original files before looking for a patch
cp project-config/build.xml build.xml
cp project-config/build-evosuite.xml build-evosuite.xml
cp project-config/pom.xml pom.xml

# If a second argument is provided, apply the patch to build-evosuite.xml and pom.xml
if [ -n "$2" ]; then
  # Check if build-evosuite.patch exists in 'project-config/subject-program'
  if [ -f "project-config/$2/build-evosuite.patch" ]; then
    echo "build-evosuite.patch found in project-config/$2. Applying patch to build-evosuite.xml..."
    patch build-evosuite.xml < "project-config/$2/build-evosuite.patch" 1>/dev/null
    rm -f build-evosuite.xml.orig
  else
    echo "No build-evosuite.patch found in project-config/$2."
    echo "build-evosuite.xml was restored to its original version..."
  fi
  # Check if pom.patch exists in 'project-config/subject-program'
  if [ -f "project-config/$2/pom.patch" ]; then
    echo "pom.patch found in project-config/$2. Applying patch to pom.xml..."
    patch pom.xml < "project-config/$2/pom.patch" 1>/dev/null
    rm -f pom.xml.orig
  else
    echo "No pom.patch found in project-config/$2."
    echo "pom.xml was restored to its original version..."
  fi
# If only one argument is provided (the subject program), apply the patch to build.xml
elif [ -n "$1" ]; then
  # Check if build.patch exists in 'project-config/subject-program'
  if [ -f "project-config/$1/build.patch" ]; then
    echo "build.patch found in project-config/$1. Applying patch to build.xml..."
    patch build.xml < "project-config/$1/build.patch" 1>/dev/null
    rm -f build.xml.orig
  else
    echo "No build.patch found in project-config/$1."
    echo "build.xml was restored to its original version..."
  fi
else
  echo "No subject-program provided. build.xml, build-evosuite.xml, and pom.xml have been restored to its original version."
fi
