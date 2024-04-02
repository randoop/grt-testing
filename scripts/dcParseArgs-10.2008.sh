#!/bin/bash

# This script does mutation testing with using the dcParseArgs-10.2008 project.

dir="../tests/src/dcParseArgs-10.2008"
repo="https://github.com/randoop/grt-dcParseArgs-10.2008.git"
jarfile="../tests/dcParseArgs-10.2008.jar"
srcDir="../tests/src/dcParseArgs-10.2008/src"

make

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "" ""