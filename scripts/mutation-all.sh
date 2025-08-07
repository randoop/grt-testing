#!/bin/sh
set -e

# This script runs `mutation-randoop.sh` on all the subject programs.
./mutation-randoop.sh "$@" a4j-1.0b
./mutation-randoop.sh "$@" asm-5.0.1
./mutation-randoop.sh "$@" bcel-5.2
./mutation-randoop.sh "$@" ClassViewer-5.0.5b
./mutation-randoop.sh "$@" commons-cli-1.2
./mutation-randoop.sh "$@" commons-codec-1.9
./mutation-randoop.sh "$@" commons-collections4-4.0
./mutation-randoop.sh "$@" commons-compress-1.8
./mutation-randoop.sh "$@" commons-lang3-3.0
./mutation-randoop.sh "$@" commons-math3-3.2
./mutation-randoop.sh "$@" commons-primitives-1.0
./mutation-randoop.sh "$@" dcParseArgs-10.2008
./mutation-randoop.sh "$@" easymock-3.2
./mutation-randoop.sh "$@" fixsuite-r48
./mutation-randoop.sh "$@" guava-16.0.1
./mutation-randoop.sh "$@" hamcrest-core-1.3
./mutation-randoop.sh "$@" javassist-3.19
./mutation-randoop.sh "$@" javax.mail-1.5.1
./mutation-randoop.sh "$@" jaxen-1.1.6
./mutation-randoop.sh "$@" jcommander-1.35
./mutation-randoop.sh "$@" jdom-1.0
./mutation-randoop.sh "$@" joda-time-2.3
./mutation-randoop.sh "$@" JSAP-2.1
./mutation-randoop.sh "$@" jvc-1.1
./mutation-randoop.sh "$@" nekomud-r16
./mutation-randoop.sh "$@" pmd-core-5.2.2
./mutation-randoop.sh "$@" sat4j-core-2.3.5
./mutation-randoop.sh "$@" shiro-core-1.2.3
./mutation-randoop.sh "$@" slf4j-api-1.7.12
./mutation-randoop.sh "$@" tiny-sql-2.26
