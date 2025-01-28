.PHONY: build/replacecall-4.3.3.jar build/major/bin/ant.m

all: \
    build/jacoco.jar \
	build/org.jacoco.agent-0.8.0-runtime.jar \
    build/randoop-all-4.3.3.jar \
    build/major \
    build/replacecall-4.3.3.jar \
    build/evosuite-1.2.0.jar \
    build/evosuite-standalone-runtime-1.2.0.jar \
    build/junit-4.12.jar \
    build/hamcrest-core-1.3.jar \
    build/major/bin/ant.m \
    results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/org.jacoco.agent-0.8.0-runtime.jar:
	mkdir -p build
	cd build && wget -nv -O org.jacoco.agent-0.8.0-runtime.jar https://repo1.maven.org/maven2/org/jacoco/org.jacoco.agent/0.8.0/org.jacoco.agent-0.8.0-runtime.jar

build/randoop-all-4.3.3.jar:
	mkdir -p build
	echo "See scripts/reprointstruction.txt to obtain randoop-all-4.3.3.jar"

build/replacecall-4.3.3.jar:
	wget https://github.com/776styjsu/randoop/releases/download/replacecall-grt-v1.0.1/replacecall-4.3.3.jar
	mv replacecall-4.3.3.jar build/

build/evosuite-1.2.0.jar:
	wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-1.2.0.jar
	mv evosuite-1.2.0.jar build/

build/evosuite-standalone-runtime-1.2.0.jar:
	wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-standalone-runtime-1.2.0.jar
	mv evosuite-standalone-runtime-1.2.0.jar build/

build/junit-4.12.jar:
	wget https://repo1.maven.org/maven2/junit/junit/4.12/junit-4.12.jar
	mv junit-4.12.jar build/

build/hamcrest-core-1.3.jar:
	cp ../subject-programs/hamcrest-core-1.3.jar build/

build/major:
	mkdir -p build
	cd build && wget -nv http://mutation-testing.org/downloads/files/major-2.2.0_jre8.zip
	cd build && unzip -o major-2.2.0_jre8.zip

build/major/bin/ant.m:
	wget https://github.com/776styjsu/randoop/releases/download/replacecall-grt-v1.0.1/ant.m
	mv ant.m build/major/bin/

results:
	mkdir -p results

clean:
	rm -rf build results evosuite-tests evosuite-report target libs 

src:
	../subject-programs/get-all-subject-src.sh

SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)

shell-script-style:
	shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms ${SH_SCRIPTS} /dev/null

showvars:
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"