all: build/jacocoagent.jar build/randoop-all-4.3.3.jar build/major results/

build/jacocoagent.jar:
	mkdir -p build
	cd build && wget -O jacoco-0.8.10.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.10/jacoco-0.8.10.zip
	cd build && unzip -o jacoco-0.8.10.zip lib/jacocoagent.jar && mv lib/jacocoagent.jar . && rmdir lib

build/randoop-all-4.3.3.jar:
	mkdir -p build
	cd build && wget https://github.com/randoop/randoop/releases/download/v4.3.3/randoop-all-4.3.3.jar

build/major:
	mkdir -p build
	cd build && wget http://mutation-testing.org/major-latest.zip
	cd build && unzip -o major-latest.zip

results/:
	mkdir -p results

clean:
	rm -rf build && rm -rf results

SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)

shell-script-style:
	shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms ${SH_SCRIPTS} /dev/null

showvars:
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
