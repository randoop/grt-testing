all: style-fix style-check

style-fix: python-style-fix shell-style-fix
style-check: python-style-check shell-style-check

install-ruff:
	@if ! command -v ruff ; then pipx install ruff ; fi

PYTHON_FILES=$(wildcard **/*.py)
python-style-fix: install-ruff
	ruff --version
	ruff format ${PYTHON_FILES}
	ruff check ${PYTHON_FILES} --fix
python-style-check: install-ruff
	ruff --version
	ruff format --check ${PYTHON_FILES}
	ruff check ${PYTHON_FILES}

SH_SCRIPTS   := $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh'   --exclude-dir=build --exclude-dir=subject-programs * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS := $(shell grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' --exclude-dir=build --exclude-dir=subject-programs * | grep -v /.git/ | grep -v '~$$' | grep -v '\.tar$$' | grep -v addrfilter | grep -v cronic-orig | grep -v gradlew | grep -v mail-stackoverflow.sh)
CHECKBASHISMS := $(shell if command -v checkbashisms > /dev/null ; then \
	  echo "checkbashisms" ; \
	else \
	  mkdir -p scripts/build ; \
	  (cd scripts/build && \
	    wget -q -N https://homes.cs.washington.edu/~mernst/software/checkbashisms; \
	    chmod +x ./checkbashisms ) ; \
	  echo "./scripts/build/checkbashisms" ; \
	fi)

shell-style-fix:
	shellcheck -x -P SCRIPTDIR --format=diff ${SH_SCRIPTS} ${BASH_SCRIPTS} | patch -p1
shell-style-check:
	shellcheck -x -P SCRIPTDIR ${SH_SCRIPTS} ${BASH_SCRIPTS}
	${CHECKBASHISMS} -l ${SH_SCRIPTS} /dev/null

showvars:
	@echo "PYTHON_FILES=${PYTHON_FILES}"
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
	@echo "CHECKBASHISMS=${CHECKBASHISMS}"
