#!/bin/bash
set -e

# This script runs `mutation.sh` on all the subject programs.
./mutation.sh "$@" a4j-1.0b
./mutation.sh "$@" asm-5.0.1
./mutation.sh "$@" bcel-5.2
./mutation.sh "$@" ClassViewer-5.0.5b
./mutation.sh "$@" commons-cli-1.2
./mutation.sh "$@" commons-codec-1.9
./mutation.sh "$@" commons-collections4-4.0
./mutation.sh "$@" commons-compress-1.8
./mutation.sh "$@" commons-lang3-3.0
./mutation.sh "$@" commons-math3-3.2
./mutation.sh "$@" commons-primitives-1.0
./mutation.sh "$@" dcParseArgs-10.2008
./mutation.sh "$@" easymock-3.2
./mutation.sh "$@" fixsuite-r48
./mutation.sh "$@" guava-16.0.1
./mutation.sh "$@" hamcrest-core-1.3
./mutation.sh "$@" javassist-3.19
./mutation.sh "$@" javax.mail-1.5.1
./mutation.sh "$@" jaxen-1.1.6
./mutation.sh "$@" jcommander-1.35
./mutation.sh "$@" jdom-1.0
./mutation.sh "$@" joda-time-2.3
./mutation.sh "$@" JSAP-2.1
./mutation.sh "$@" jvc-1.1
./mutation.sh "$@" nekomud-r16
./mutation.sh "$@" pmd-core-5.2.2
./mutation.sh "$@" sat4j-core-2.3.5
./mutation.sh "$@" shiro-core-1.2.3
./mutation.sh "$@" slf4j-api-1.7.12
./mutation.sh "$@" tiny-sql-2.26
