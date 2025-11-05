all: style-fix style-check

clean:
	rm -rf "$GRT_TESTING_ROOT"/build/bin/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-report/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/lib/*
	rm -rf "$GRT_TESTING_ROOT"/build/randoop-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/target/*


###########################################################################
### Style
###

style-fix: python-style-fix shell-style-fix
style-check: python-style-check python-typecheck shell-style-check

PYTHON_FILES:=$(wildcard *.py) $(wildcard **/*.py) $(shell grep -r -l --exclude='*.py' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git '^\#! \?\(/bin/\|/usr/bin/env \)python')
PYTHON_FILES_TO_CHECK:=$(filter-out ${lcb_runner},${PYTHON_FILES})
python-style-fix:
ifneq (${PYTHON_FILES_TO_CHECK},)
	@ruff --version
	@ruff format ${PYTHON_FILES_TO_CHECK}
	@ruff -q check ${PYTHON_FILES_TO_CHECK} --fix
endif
python-style-check:
ifneq (${PYTHON_FILES_TO_CHECK},)
	@ruff --version
	@ruff -q format --check ${PYTHON_FILES_TO_CHECK}
	@ruff -q check ${PYTHON_FILES_TO_CHECK}
endif
python-typecheck:
ifneq (${PYTHON_FILES_TO_CHECK},)
	@mypy --strict --install-types --non-interactive ${PYTHON_FILES_TO_CHECK} > /dev/null 2>&1 || true
	mypy --strict --ignore-missing-imports ${PYTHON_FILES_TO_CHECK}
endif

SH_SCRIPTS   := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)sh')
BASH_SCRIPTS := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)bash')
CHECKBASHISMS := $(shell if command -v checkbashisms > /dev/null ; then \
	  echo "checkbashisms" ; \
	else \
	  mkdir -p scripts/build && \
	  (cd scripts/build && \
	    wget -q -N https://homes.cs.washington.edu/~mernst/software/checkbashisms && \
	    chmod +x ./checkbashisms ) && \
	  echo "./scripts/build/checkbashisms" ; \
	fi)
shell-style-fix:
ifneq ($(SH_SCRIPTS)$(BASH_SCRIPTS),)
	@shfmt -w -i 2 -ci -bn -sr ${SH_SCRIPTS} ${BASH_SCRIPTS}
	@shellcheck -x -P SCRIPTDIR --format=diff ${SH_SCRIPTS} ${BASH_SCRIPTS} | patch -p1
endif
shell-style-check:
ifneq ($(SH_SCRIPTS)$(BASH_SCRIPTS),)
	@shfmt -d -i 2 -ci -bn -sr ${SH_SCRIPTS} ${BASH_SCRIPTS}
	@shellcheck -x -P SCRIPTDIR --format=gcc ${SH_SCRIPTS} ${BASH_SCRIPTS}
endif
ifneq ($(SH_SCRIPTS),)
	@${CHECKBASHISMS} -l ${SH_SCRIPTS}
endif

style-fix: markdownlint-fix
markdownlint-fix:
	markdownlint-cli2 --fix .
style-check: markdownlint-check
markdownlint-check:
	markdownlint-cli2 .

showvars:
	@echo "PYTHON_FILES=${PYTHON_FILES}"
	@echo "PYTHON_FILES_TO_CHECK=${PYTHON_FILES_TO_CHECK}"
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
	@echo "CHECKBASHISMS=${CHECKBASHISMS}"
