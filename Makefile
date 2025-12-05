all: style-fix style-check

clean:
	rm -rf "$GRT_TESTING_ROOT"/build/bin/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-report/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/lib/*
	rm -rf "$GRT_TESTING_ROOT"/build/randoop-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/target/*

.plume-scripts:
	git clone -q https://github.com/plume-lib/plume-scripts.git .plume-scripts


###########################################################################
### Style
###

# Dependencies appear below.
style-fix:
style-check:

style-fix: python-style-fix
style-check: python-style-check python-typecheck
PYTHON_FILES:=$(wildcard **/*.py) $(shell grep -r -l --exclude='*.py' --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude=lcb_runner --exclude-dir=.git --exclude-dir=.venv '^\#! \?\(/bin/\|/usr/bin/\|/usr/bin/env \)python')
python-style-fix:
ifneq (${PYTHON_FILES},)
	@uvx ruff --version
	@uvx ruff format ${PYTHON_FILES}
	@uvx ruff -q check ${PYTHON_FILES} --fix
endif
python-style-check:
ifneq (${PYTHON_FILES},)
	@uvx ruff --version
	@uvx ruff -q format --check ${PYTHON_FILES}
	@uvx ruff -q check ${PYTHON_FILES}
endif
python-typecheck:
ifneq (${PYTHON_FILES},)
	@uv run ty check -q
endif
showvars::
	@echo "PYTHON_FILES=${PYTHON_FILES}"

style-fix: shell-style-fix
style-check: shell-style-check
SH_SCRIPTS   := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)sh')
BASH_SCRIPTS := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git --exclude-dir=build --exclude-dir=subject-programs '^\#! \?\(/bin/\|/usr/bin/env \)bash')
CHECKBASHISMS := $(shell if command -v checkbashisms > /dev/null ; then \
  echo "checkbashisms" ; \
else \
  wget -q -N https://homes.cs.washington.edu/~mernst/software/checkbashisms && \
  mv checkbashisms .checkbashisms && \
  chmod +x ./.checkbashisms && \
  echo "./.checkbashisms" ; \
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
showvars::
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
	@echo "CHECKBASHISMS=${CHECKBASHISMS}"

style-fix: markdownlint-fix
markdownlint-fix:
	markdownlint-cli2 --fix "**/*.md" "#node_modules"
style-check: markdownlint-check
markdownlint-check:
	markdownlint-cli2 "**/*.md" "#node_modules"
