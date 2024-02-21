#!/bin/bash

# This script does mutation testing with using the jcommander-1.35 project.

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