#!/bin/bash

# This script does mutation testing with using the ClassViewer-5.0.5b project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/ClassViewer-5.0.5b"
repo="https://github.com/randoop/grt-ClassViewer-5.0.5b.git"
jarfile="../tests/ClassViewer-5.0.5b.jar"
srcDir="../tests/src/ClassViewer-5.0.5b/"
additionalArgs="--usethreads=true"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "" "$additionalArgs"
