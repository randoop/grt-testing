#!/bin/bash

# This script does mutation testing with using the commons-cli-1.2 project.

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