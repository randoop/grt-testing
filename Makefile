all: style-fix style-check

style-fix: python-style-fix shell-style-fix
style-check: python-style-check shell-style-check

PYTHON_FILES=$(wildcard **/*.py)
python-style-fix:
	ruff --version
	ruff format ${PYTHON_FILES}
	ruff check ${PYTHON_FILES} --fix
python-style-check:
	ruff --version
	ruff format --check ${PYTHON_FILES}
	ruff check ${PYTHON_FILES}

SH_SCRIPTS   = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS = $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
shell-style-fix:
	shellcheck -x -P SCRIPTDIR --format=diff ${SH_SCRIPTS} ${BASH_SCRIPTS} | patch -p1
shell-style-check:
	shellcheck -x -P SCRIPTDIR --format=diff ${SH_SCRIPTS} ${BASH_SCRIPTS}
	checkbashisms -l ${SH_SCRIPTS} /dev/null

showvars:
	@echo "PYTHON_FILES=${PYTHON_FILES}"
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
