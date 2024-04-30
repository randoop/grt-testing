#!/bin/bash

# This script does mutation testing with using the Java View Control 1.1 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/jvc-1.1"
repo="https://github.com/randoop/grt-jvc-1.1.git"
jarfile="../tests/jvc-1.1.jar"
srcDir="../tests/src/jvc-1.1/src"
alt_jarfiles=("../tests/src/jvc-1.1/lib/")

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "$alt_jarfiles" ""
