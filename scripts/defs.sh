#!/bin/bash

# This file defines shell functions.

append_csv() {
  local csv_file="$1"
  local header="$2"
  shift 2

  {
    exec {fd}>> "$csv_file"
    flock "$fd"

    # Write header if file is empty
    if [ ! -s "$csv_file" ]; then
      echo "$header" >&"$fd"
    fi

    # Run the caller's commands inside the file lock
    # shellcheck disable=SC2294
    eval "$@" >&"$fd"

    exec {fd}>&-
  }
}

require_file() {
  [ -f "$1" ] || {
    echo "${SCRIPT_NAME}: error: Missing file $1" >&2
    exit 2
  }
}

require_directory() {
  [ -d "$1" ] || {
    echo "${SCRIPT_NAME}: error: Missing directory $1" >&2
    exit 2
  }
}

require_csv_basename() {
  if [[ "$1" == */* ]]; then
    echo "${SCRIPT_NAME}: error: -o expects a filename only (no paths). Given: $1" >&2
    exit 2
  fi
  if [[ "$1" != *.csv ]]; then
    echo "${SCRIPT_NAME}: error: -o must end with .csv.  Given: $1" >&2
    exit 2
  fi
}

# Switch to Java 8.
usejdk8() {
  if [ -z "$JAVA8_HOME" ]; then
    echo "Error: JAVA8_HOME is not set." >&2
    return 1
  fi
  export JAVA_HOME="$JAVA8_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Switched to Java 8 ($JAVA_HOME)"
}

# Switch to Java 11.
usejdk11() {
  if [ -z "$JAVA11_HOME" ]; then
    echo "Error: JAVA11_HOME is not set." >&2
    return 1
  fi
  export JAVA_HOME="$JAVA11_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Switched to Java 11 ($JAVA_HOME)"
}
