#!/bin/sh

###
### This file is copied from
### https://github.com/plume-lib/manage-git-branches/blob/main/compile-project
###

# Compile the project that contains the current or given directory.
#
# Supports Gradle, Maven, and Make projects.  If no buildfile is found
# at the top level, searches at (only) the next level down.
#
# The exit status is failure if any build fails.  If no buildfile is
# found and ERR_IF_NO_BUILDFILE is set to a non-empty value, then the
# exit status is failure.
#
# Usage:
#   compile-project [<directory>]
#
# If variable GRADLE_ASSEMBLE_FLAGS is defined, it is passed to `gradle assemble`.
# If variable MVN_COMPILE_FLAGS is defined, it is passed to `mvn compile`.
# If variable MAKE_FLAGS is defined, it is passed to `make`.
# If variable ERR_IF_NO_BUILDFILE is non-empty, the script fails if no buildfile is found.
#
# This command does not need to be run in the top-level directory of the project;
# it will discover the top-level directory on its own and run the command there.

# TODO: Handle other build systems too, such as Ant.
# TODO: Have a list of per-directory or per-repository commands, to override the default.

# $toplevel does not have a trailing "/" character
if [ "$#" -eq 0 ]; then
  if toplevel="$(git rev-parse --show-toplevel 2>&1)" ; then
    echo "Running $(basename "$0") in $toplevel, called from $(pwd)"
  else
    toplevel=$(pwd)
    echo "Running $(basename "$0") in $toplevel"
  fi
elif [ "$#" -eq 1 ]; then
  toplevel="$1"
  echo "Running $(basename "$0") in $toplevel"
else
  echo "Usage: $(basename "$0") [<directory>]" >&2
  exit 1
fi

# Returns a status code indicating success or failure, or 222 if no buildfile was found.
compile_in_directory() {
  if [ "$#" -ne 1 ] ; then
    echo "compile_in_directory got $# arguments: $*"
    exit 1
  fi
  dir="$1"

  if [ -f "$dir/gradlew" ]; then
    # shellcheck disable=SC2086 # Word splitting is desirable here.
    "$dir/gradlew" --project-dir "$dir" assemble -q ${GRADLE_ASSEMBLE_FLAGS} < /dev/null
    return $?
  elif [ -f "$dir/build.gradle" ]; then
    # shellcheck disable=SC2086 # Word splitting is desirable here.
    gradle --project-dir "$dir" assemble -q ${GRADLE_ASSEMBLE_FLAGS} < /dev/null
    return $?
  elif [ -f "$dir/mvnw" ]; then
    # shellcheck disable=SC2086 # Word splitting is desirable here.
    (cd "$dir" && ./mvnw -q compile ${MVN_COMPILE_FLAGS})
    return $?
  elif [ -f "$dir/pom.xml" ]; then
    # shellcheck disable=SC2086 # Word splitting is desirable here.
    (cd "$dir" && mvn -q compile ${MVN_COMPILE_FLAGS})
    return $?
  elif [ -f "$dir/Makefile" ]; then
    # shellcheck disable=SC2086 # Word splitting is desirable here.
    (cd "$dir" && make ${MAKE_FLAGS})
    return $?
  else
    # No buildfile was found.
    return 222
  fi
}

compile_in_directory "$toplevel"
result=$?

if [ "$result" != 222 ] ; then
  # A buildfile was found; exit with the exit code of the compilation step.
  exit $result
else
  # Call compile_in_directory in subdirectories.
  buildfile_found=0
  for subdir in "$toplevel"/*/ ; do
    compile_in_directory "$subdir"
    result=$?
    if [ "$result" = 222 ] ; then
      continue
    fi
    buildfile_found=1
    if [ ! $result ] ; then
      exit $result
    fi
  done
  if [ "$buildfile_found" = 0 ] && [ -n "$ERR_IF_NO_BUILDFILE" ]; then
    echo "compile-project did nothing in $(pwd)"
    exit 1
  fi
fi
