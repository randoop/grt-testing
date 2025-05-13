#!/bin/sh

# This script clones the repositories for each subject program, in
# subject-programs/src/. If the repository already exists, it pulls the
# latest changes.

SCRIPT_DIR="$(cd "$(dirname "$0")" > /dev/null 2>&1 && pwd -P)"

SUBJECT_SRC_DIR="${SCRIPT_DIR}/../subject-programs/src"
mkdir -p "${SUBJECT_SRC_DIR}"
cd "${SUBJECT_SRC_DIR}" || (echo "Directory does not exist: ${SUBJECT_SRC_DIR}" && exit 2)

grt_clone() {
  printf '%s:' "$1"
  if [ -d "$1" ]; then
    echo " updating."
    (cd "$1" && git pull -q)
  else
    echo " cloning."
    git clone -q git@github.com:randoop/grt-"$1" "$1"
  fi
}

grt_clone a4j-1.0b
grt_clone asm-5.0.1
grt_clone bcel-5.2
grt_clone ClassViewer-5.0.5b
grt_clone commons-cli-1.2
grt_clone commons-codec-1.9
grt_clone commons-collections4-4.0
grt_clone commons-compress-1.8
grt_clone commons-lang3-3.0
grt_clone commons-math3-3.2
grt_clone commons-primitives-1.0
grt_clone dcParseArgs-10.2008
grt_clone easymock-3.2
grt_clone fixsuite-r48
grt_clone guava-16.0.1
grt_clone hamcrest-core-1.3
grt_clone javassist-3.19
grt_clone javax.mail-1.5.1
grt_clone jaxen-1.1.6
grt_clone jcommander-1.35
grt_clone jdom-1.0
grt_clone joda-time-2.3
grt_clone JSAP-2.1
grt_clone jvc-1.1
grt_clone nekomud-r16
grt_clone pmd-core-5.2.2
grt_clone sat4j-core-2.3.5
grt_clone shiro-core-1.2.3
grt_clone slf4j-api-1.7.12
grt_clone tiny-sql-2.26
