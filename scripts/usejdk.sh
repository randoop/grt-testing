#!/bin/sh

# This file defines shell functions to switch to JDK 8 and JDK 11, respectively.

# Ensure the user has set both JAVA8_HOME and JAVA11_HOME
if [ -z "$JAVA8_HOME" ]; then
    echo "Error: JAVA8_HOME is not set."
    exit 1
fi

if [ -z "$JAVA11_HOME" ]; then
    echo "Error: JAVA11_HOME is not set."
    exit 1
fi

# Switch to Java 8
usejdk8() {
    export JAVA_HOME="$JAVA8_HOME"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "Switched to Java 8 ($JAVA_HOME)"
}

# Switch to Java 11
usejdk11() {
    export JAVA_HOME="$JAVA11_HOME"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "Switched to Java 11 ($JAVA_HOME)"
}
