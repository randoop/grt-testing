MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: build/jacoco.jar build/randoop-all-4.3.3.jar build/randoop build/major results/

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/randoop-all-4.3.3.jar:
	mkdir -p build
	cd build
	wget -nv https://github.com/randoop/randoop/releases/download/v4.3.3/randoop-all-4.3.3.jar

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
	./gradlew shadowJar && \
	mv -f build/libs/randoop-all-4.3.3.jar agent/replacecall/build/libs/replacecall-4.3.3.jar ..

build/libs/randoop-all-4.3.3.jar:
	mv -f build/libs/randoop-all-4.3.3.jar agent/replacecall/build/libs/replacecall-4.3.3.jar ..

results:
	mkdir -p results

clean:
	rm -rf build results

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
