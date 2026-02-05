all: style-fix style-check

# Code style; defines `style-check` and `style-fix`.
CODE_STYLE_EXCLUSIONS_USER := --exclude-dir subject-programs
ifeq (,$(wildcard .plume-scripts))
dummy := $(shell git clone -q https://github.com/plume-lib/plume-scripts.git .plume-scripts)
endif
include .plume-scripts/code-style.mak
