#!/bin/sh

set -e

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1 | sed 's/-ea//')
if [ "$JAVA_VER" != "8" ]; then
  echo "Use Java 8"
  exit 2
fi

# The commands are taken from file `README.build`.

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
# SCRIPT_NAME=$(basename -- "$0")

"${SCRIPT_DIR}"/../scripts/get-all-subject-src.sh

cd "${SCRIPT_DIR}"/src || exit 2

(cd a4j-1.0b \
  && ant createJar)

(cd asm-5.0.1 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd bcel-5.2 \
  && ant jar)

(cd ClassViewer-5.0.5b \
  && ant build)

(cd commons-cli-1.2 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-codec-1.9 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-collections4-4.0 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-compress-1.8 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-lang3-3.0 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-math3-3.2 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd commons-primitives-1.0 \
  && ant jar)

(cd dcParseArgs-10.2008 \
  && ant createJar)

(cd easymock-3.2 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd fixsuite-r48 \
  && ant jar)

(cd guava-16.0.1 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd hamcrest-core-1.3 \
  && ant core)

(cd javassist-3.19 \
  && ant jar)

(cd jaxax.mail-1.5.1 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd jaxen-1.1.6 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd jcommander-1.35 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd jdom-1.0 \
  && ./build.sh)

(cd joda-time-2.3 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd JSAP-2.1 \
  && ant jar)

(cd jvc-1.1 \
  && ant tools)

(cd nekomud-r16 \
  && ant)

(cd pmd-core-5.2.2/pmd-core \
  && mvn -B clean package -Dmaven.test.skip -Dmaven.javadoc.skip -DjavaccBuildNotRequired)

(cd sat4j.core-2.3.5 \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd shiro-core-1.2.3/core \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

(cd slf4j-api-1.7.12/slf4j-api \
  && mvn -B clean package -Dmaven.test.failure.ignore -Dmaven.javadoc.skip 2>&1 | tee mvn-output.txt)

usejdk8
(cd tiny-sql-2.26 \
  && ./build.sh)
