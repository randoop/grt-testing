MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: \
    build/jacoco.jar \
    build/org.jacoco.agent-0.8.0-runtime.jar \
    build/randoop-all-4.3.3.jar \
    build/major \
    build/randoop \
    build/replacecall-4.3.3.jar \
    build/evosuite-1.2.0.jar \
    build/evosuite-standalone-runtime-1.2.0.jar \
    build/junit-4.12.jar \
    build/junit-4.13.2.jar \
    build/hamcrest-core-1.3.jar \
    build/major/bin/ant.m \
    build/major/bin/ant-replacecall \
    results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/org.jacoco.agent-0.8.0-runtime.jar:
	mkdir -p build
	cd build && wget -nv -O org.jacoco.agent-0.8.0-runtime.jar https://repo1.maven.org/maven2/org/jacoco/org.jacoco.agent/0.8.0/org.jacoco.agent-0.8.0-runtime.jar

# Currently, we build randoop from source instead of downloading the jar
build/randoop-all-4.3.3.jar:
	# mkdir -p build
	# cd build
	# wget -nv https://github.com/randoop/randoop/releases/download/v4.3.3/randoop-all-4.3.3.jar
	echo "See scripts/reproinstruction.txt to obtain randoop-all-4.3.3.jar"

build/major:
	mkdir -p build
	cd build && wget -nv https://mutation-testing.org/downloads/files/major-2.2.0_jre8.zip
	cd build && unzip -o major-2.2.0_jre8.zip

build/randoop:
	mkdir -p build
	cd build && git clone git@github.com:randoop/randoop.git

randoop-from-source:
	cd build/randoop && \
	git pull && \
	./gradlew jar && \
	mv -f build/libs/randoop-all-4.3.3.jar ..

build/replacecall-4.3.3.jar:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/replacecall-4.3.3.jar" && \
	mv replacecall-4.3.3.jar build/

build/evosuite-1.2.0.jar:
	mkdir -p build
	cd build && wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-1.2.0.jar

build/evosuite-standalone-runtime-1.2.0.jar:
	mkdir -p build
	cd build && wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-standalone-runtime-1.2.0.jar

build/junit-4.12.jar:
	mkdir -p build
	cd build && wget https://repo1.maven.org/maven2/junit/junit/4.12/junit-4.12.jar

build/junit-4.13.2.jar:
	mkdir -p build
	cd build && wget https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar

build/hamcrest-core-1.3.jar:
	mkdir -p build
	cp ../subject-programs/hamcrest-core-1.3.jar build/

build/major/bin/ant-replacecall:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/ant-replacecall" && \
	mv ant-replacecall build/major/bin/

results:
	mkdir -p results

clean:
	rm -rf build results evosuite-tests evosuite-report target libs 

src:
	get-all-subject-src.sh

SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh | grep -v build/)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh | grep -v build/)

shell-script-style:
	shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms ${SH_SCRIPTS} /dev/null

showvars:
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
