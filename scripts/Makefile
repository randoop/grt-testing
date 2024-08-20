all: build/jacocoagent.jar build/randoop-all-4.3.3.jar build/major results/ src/

build/jacocoagent.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.10.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.10/jacoco-0.8.10.zip
	cd build && unzip -o jacoco-0.8.10.zip lib/jacocoagent.jar && mv lib/jacocoagent.jar . && rmdir lib

build/randoop-all-4.3.3.jar:
	mkdir -p build
	cd build && wget -nv https://github.com/randoop/randoop/releases/download/v4.3.3/randoop-all-4.3.3.jar

build/major:
	mkdir -p build
	cd build && wget -nv http://mutation-testing.org/major-latest.zip
	cd build && unzip -o major-latest.zip

results/:
	mkdir -p results

clean:
	rm -rf build && rm -rf results

REPOS := \
    git@github.com:randoop/grt-a4j-1.0b.git \
    git@github.com:randoop/grt-asm-5.0.1.git \
    git@github.com:randoop/grt-bcel-5.2.git \
    git@github.com:randoop/grt-ClassViewer-5.0.5b.git \
    git@github.com:randoop/grt-commons-cli-1.2.git \
    git@github.com:randoop/grt-commons-codec-1.9.git \
    git@github.com:randoop/grt-commons-collections4-4.0.git \
    git@github.com:randoop/grt-commons-compress-1.8.git \
    git@github.com:randoop/grt-commons-lang3-3.0.git \
    git@github.com:randoop/grt-commons-math3-3.2.git \
    git@github.com:randoop/grt-commons-primitives-1.0.git \
    git@github.com:randoop/grt-dcParseArgs-10.2008.git \
    git@github.com:randoop/grt-easymock-3.2.git \
    git@github.com:randoop/grt-fixsuite-r48.git \
    git@github.com:randoop/grt-guava-16.0.1.git \
    git@github.com:randoop/grt-hamcrest-core-1.3.git \
    git@github.com:randoop/grt-javassist-3.19.git \
    git@github.com:randoop/grt-jaxax.mail-1.5.1.git \
    git@github.com:randoop/grt-jaxen-1.1.6.git \
    git@github.com:randoop/grt-jcommander-1.35.git \
    git@github.com:randoop/grt-jdom-1.0.git \
    git@github.com:randoop/grt-joda-time-2.3.git \
    git@github.com:randoop/grt-JSAP-2.1.git \
    git@github.com:randoop/grt-jvc-1.1.git \
    git@github.com:randoop/grt-nekomud-r16.git \
    git@github.com:randoop/grt-pmd-core-5.2.2.git \
    git@github.com:randoop/grt-sat4j.core-2.3.5.git \
    git@github.com:randoop/grt-shiro-root-1.2.3.git \
    git@github.com:randoop/grt-slf4j-api-1.7.12.git \
    git@github.com:randoop/grt-tiny-sql-2.26.git

SRC_DIR := ../src

src/:
	mkdir -p $(SRC_DIR)
	for repo in $(REPOS); do \
	    repo_name=$$(basename $$repo .git); \
	    git clone $$repo $(SRC_DIR)/$$repo_name; \
	done

SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)

shell-script-style:
	shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms ${SH_SCRIPTS} /dev/null

showvars:
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
