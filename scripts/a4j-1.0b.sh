#!/bin/bash

# This script does mutation testing with using the commons-cli-1.2 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/a4j-1.0b"
repo="https://github.com/randoop/grt-a4j-1.0b.git"
jarfile="../tests/a4j-1.0b.jar"
srcDir="../tests/src/a4j-1.0b/src"
alt="../tests/src/a4j-1.0b/jars"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "$alt" ""
