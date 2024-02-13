#!/bin/bash

# This script does mutation testing with using the commons-cli-1.2 project.

dir="../tests/src/commons-cli-1.2"
repo="https://github.com/randoop/grt-commons-cli-1.2.git"
jarfile="../tests/commons-cli-1.2.jar"
srcDir="../tests/src/commons-cli-1.2/src/java"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" ""