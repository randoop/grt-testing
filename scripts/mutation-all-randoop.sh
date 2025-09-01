#!/bin/sh
set -eu

# Directory of this script.
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)

subjects="
a4j-1.0b
asm-5.0.1
bcel-5.2
ClassViewer-5.0.5b
commons-cli-1.2
commons-codec-1.9
commons-collections4-4.0
commons-compress-1.8
commons-lang3-3.0
commons-math3-3.2
commons-primitives-1.0
dcParseArgs-10.2008
easymock-3.2
fixsuite-r48
guava-16.0.1
hamcrest-core-1.3
javassist-3.19
javax.mail-1.5.1
jaxen-1.1.6
jcommander-1.35
jdom-1.0
joda-time-2.3
JSAP-2.1
jvc-1.1
nekomud-r16
pmd-core-5.2.2
sat4j-core-2.3.5
shiro-core-1.2.3
slf4j-api-1.7.12
tiny-sql-2.26
"

for s in $subjects; do
  "$SCRIPT_DIR/mutation-randoop.sh" "$@" "$s"
done
