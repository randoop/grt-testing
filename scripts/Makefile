MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: build/jacoco.jar build/major build/major/bin/ant-replacecall build/randoop-all-4.3.4.jar build/randoop build/replacecall-4.3.3.jar results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/randoop-all-4.3.4.jar:
	# mkdir -p build
	# cd build
	# wget -nv https://github.com/randoop/randoop/releases/download/v4.3.4/randoop-all-4.3.4.jar
	echo "See scripts/reproinstruction.txt to obtain randoop-all-4.3.4.jar"

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
	mv -f build/libs/randoop-all-4.3.4.jar ..

build/replacecall-4.3.3.jar:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/replacecall-4.3.3.jar" && \
	mv replacecall-4.3.3.jar build/

build/major/bin/ant-replacecall:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/ant-replacecall" && \
	mv ant-replacecall build/major/bin/

results:
	mkdir -p results

clean:
	rm -rf build results

src:
	get-all-subject-src.sh

### Code style

fix-style: python-style-fix shell-style-fix
# TODO: add python-typecheck here
check-style: python-style-check shell-style-check


PYTHON_FILES:=$(wildcard *.py) $(wildcard **/*.py) $(shell grep -r -l --exclude='*.py' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git '^\#! \?\(/bin/\|/usr/bin/env \)python')
PYTHON_FILES_TO_CHECK:=$(filter-out ${lcb_runner},${PYTHON_FILES})
install-mypy:
	@if ! command -v mypy ; then pip install mypy ; fi
install-ruff:
	@if ! command -v ruff ; then pipx install ruff ; fi
python-style-fix: install-ruff
ifneq (${PYTHON_FILES},)
	@ruff format ${PYTHON_FILES_TO_CHECK}
	@ruff -q check ${PYTHON_FILES_TO_CHECK} --fix
endif
python-style-check: install-ruff
ifneq (${PYTHON_FILES_TO_CHECK},)
	@ruff -q format --check ${PYTHON_FILES_TO_CHECK}
	@ruff -q check ${PYTHON_FILES_TO_CHECK}
endif
python-typecheck: install-mypy
ifneq (${PYTHON_FILES_TO_CHECK},)
	@mypy --strict --install-types --non-interactive ${PYTHON_FILES_TO_CHECK} > /dev/null 2>&1 || true
	mypy --strict --ignore-missing-imports ${PYTHON_FILES_TO_CHECK}
endif

SH_SCRIPTS   := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git '^\#! \?\(/bin/\|/usr/bin/env \)sh'   | grep -v addrfilter | grep -v cronic-orig | grep -v mail-stackoverflow.sh)
BASH_SCRIPTS := $(shell grep -r -l --exclude='#*' --exclude='*~' --exclude='*.tar' --exclude=gradlew --exclude-dir=.git '^\#! \?\(/bin/\|/usr/bin/env \)bash' | grep -v addrfilter | grep -v cronic-orig | grep -v mail-stackoverflow.sh)
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

showvars:
	@echo "PYTHON_FILES=${PYTHON_FILES}"
	@echo "PYTHON_FILES_TO_CHECK=${PYTHON_FILES_TO_CHECK}"
	@echo "SH_SCRIPTS=${SH_SCRIPTS}"
	@echo "BASH_SCRIPTS=${BASH_SCRIPTS}"
