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

SH_SCRIPTS   := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)sh'   | grep -v addrfilter | grep -v cronic-orig | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)bash' | grep -v addrfilter | grep -v cronic-orig | grep -v mail-stackoverflow.sh)
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
	@shfmt -w -i 2 -ci -bn -sr ${SH_SCRIPTS} ${BASH_SCRIPTS}
	@shellcheck -x -P SCRIPTDIR --format=diff ${SH_SCRIPTS} ${BASH_SCRIPTS} | patch -p1
shell-style-check:
	@shfmt -d -i 2 -ci -bn -sr ${SH_SCRIPTS} ${BASH_SCRIPTS}
	@shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
	@${CHECKBASHISMS} -l ${SH_SCRIPTS}

showvars:
	@echo "PYTHON_FILES=${PYTHON_FILES}"
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
	@echo "CHECKBASHISMS=${CHECKBASHISMS}"
