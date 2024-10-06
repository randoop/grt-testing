all: build/jacoco.jar build/randoop-all-4.3.3.jar build/major results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/randoop-all-4.3.3.jar:
	mkdir -p build
	echo "See scripts/reprointstruction.txt to obtain randoop-all-4.3.3.jar"

build/major:
	mkdir -p build
	cd build && wget -nv http://mutation-testing.org/downloads/files/major-2.2.0_jre8.zip
	cd build && unzip -o major-2.2.0_jre8.zip

build/major:
	wget https://github.com/776styjsu/grt-replacecall/releases/download/v0.1.0/replacecall-4.3.3.jar
	mv replacecall-4.3.3.jar build/

results:
	mkdir -p results

clean:
	rm -rf build && rm -rf results

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
