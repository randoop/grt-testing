#!/bin/bash

# This script does mutation testing with using the ClassViewer-5.0.5b project.

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