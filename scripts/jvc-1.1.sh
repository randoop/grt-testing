#!/bin/bash

# This script does mutation testing with using the Java View Control 1.1 project.

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