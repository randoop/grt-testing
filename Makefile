all: style-fix style-check

clean:
	rm -rf "$GRT_TESTING_ROOT"/build/bin/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-report/*
	rm -rf "$GRT_TESTING_ROOT"/build/evosuite-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/lib/*
	rm -rf "$GRT_TESTING_ROOT"/build/randoop-tests/*
	rm -rf "$GRT_TESTING_ROOT"/build/target/*


# Code style; defines `style-check` and `style-fix`.
CODE_STYLE_EXCLUSIONS_USER := --exclude-dir subject-programs
ifeq (,$(wildcard .plume-scripts))
dummy := $(shell git clone -q https://github.com/plume-lib/plume-scripts.git .plume-scripts)
endif
include .plume-scripts/code-style.mak
