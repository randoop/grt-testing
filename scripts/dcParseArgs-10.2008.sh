#!/bin/bash

# This script does mutation testing with using the dcParseArgs-10.2008 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir="../tests/src/dcParseArgs-10.2008"
repo="https://github.com/randoop/grt-dcParseArgs-10.2008.git"
jarfile="../tests/dcParseArgs-10.2008.jar"
srcDir="../tests/src/dcParseArgs-10.2008/src"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "" ""
