#!/bin/sh

# This file defines shell functions to switch to JDK 8 and JDK 11, respectively.

# Switch to Java 8
usejdk8() {
  if [ -z "$JAVA8_HOME" ]; then
    echo "Error: JAVA8_HOME is not set." >&2
    return 1
  fi
  export JAVA_HOME="$JAVA8_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Switched to Java 8 ($JAVA_HOME)"
}

# Switch to Java 11
usejdk11() {
  if [ -z "$JAVA11_HOME" ]; then
    echo "Error: JAVA11_HOME is not set." >&2
    return 1
  fi
  export JAVA_HOME="$JAVA11_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Switched to Java 11 ($JAVA_HOME)"
}
