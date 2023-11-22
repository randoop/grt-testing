all: jarfiles/jacocoagent.jar jarfiles/randoop-all-4.3.2.jar

jarfiles/jacocoagent.jar:
	mkdir -p jarfiles
	# TODO: Why does this delete everything?  Why not just delete the relevant files?
	# Or, you can use the `-o` command-line option to `unzip` to overwrite existing files.
	cd jarfiles && find -type f -exec rm {} +
	cd jarfiles && wget -O jacoco-0.8.10.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.10/jacoco-0.8.10.zip
	cd jarfiles && unzip jacoco-0.8.10.zip lib/jacocoagent.jar


jarfiles/randoop-all-4.3.2.jar:
	mkdir -p jarfiles
	cd jarfiles && wget https://github.com/randoop/randoop/releases/download/v4.3.2/randoop-all-4.3.2.jar


SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)

shell-script-style:
	shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms ${SH_SCRIPTS} /dev/null

showvars:
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
