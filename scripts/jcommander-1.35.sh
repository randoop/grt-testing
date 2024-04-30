#!/bin/bash

# This script does mutation testing with using the jcommander-1.35 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/jcommander-1.35"
repo="https://github.com/randoop/grt-jcommander-1.35.git"
jarfile="../tests/jcommander-1.35.jar"
srcDir="../tests/src/jcommander-1.35/src/main"
additionalArgs="--usethreads=true"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "" "$additionalArgs"
