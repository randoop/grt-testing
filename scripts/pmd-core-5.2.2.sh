#!/bin/bash

# This script does mutation testing with using the pmd-core-5.2.2 project.

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
[ "$JAVA_VER" = "8" ] || echo "Use Java 8, not $JAVA_VER.  Aborting."
[ "$JAVA_VER" = "8" ] || exit 2

dir=$(realpath "../tests/src/pmd-dcd-5.2.2")
repo="https://github.com/randoop/grt-pmd-dcd-5.2.2"
jarfile=$(realpath "../tests/pmd-core-5.2.2.jar")
srcDir=$(realpath "../tests/src/pmd-dcd-5.2.2/pmd-core/src/main/java")
alt=$(realpath "build/alt_jarfiles")

make
cd build && mkdir -p alt_jarfiles && cd alt_jarfiles && wget -nv https://repository.ow2.org/nexus/content/repositories/releases/org/ow2/asm/asm/9.5/asm-9.5.jar

if [ ! -d "$dir" ]; then
    git clone "$repo" "$dir"
fi

cd .. && cd ..
./mutation.sh "$jarfile" "$srcDir" "$alt" ""
