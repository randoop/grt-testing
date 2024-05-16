#!/bin/bash

# This script does mutation testing with using the commons-cli-1.2 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/commons-cli-1.2"
repo="https://github.com/randoop/grt-commons-cli-1.2.git"
# repo="git@github.com:randoop/grt-commons-cli-1.2.git"
jarfile="../tests/commons-cli-1.2.jar"
srcDir="../tests/src/commons-cli-1.2/src/java"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "" ""
