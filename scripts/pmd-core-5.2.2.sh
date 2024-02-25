#!/bin/bash

# This script does mutation testing with using the pmd-core-5.2.2 project.

dir=$(realpath "../tests/src/pmd-dcd-5.2.2")
repo="https://github.com/randoop/grt-pmd-dcd-5.2.2"
jarfile=$(realpath "../tests/pmd-core-5.2.2.jar")
srcDir=$(realpath "../tests/src/pmd-dcd-5.2.2/pmd-core/src/main/java")
alt=$(realpath "build/alt_jarfiles")

make
cd build && mkdir alt_jarfiles && cd alt_jarfiles && wget -nv https://repository.ow2.org/nexus/content/repositories/releases/org/ow2/asm/asm/9.5/asm-9.5.jar

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

./mutation.sh "$jarfile" "$srcDir" "$alt" ""