#!/usr/bin/env bash

#===============================================================================
# buildjars.sh
#===============================================================================
#
# Purpose
# -------
# Prepare Defects4J fixed-version source trees and run Checker Framework
# inference to generate purity annotations for each (PROJECT_ID, BUG_ID) pair.
#
# This script does NOT produce the final project jar by itself.
# It only performs:
#   1) checkout of each Defects4J fixed revision
#   2) purity inference / annotation over source files
#
# You must then build/package each project independently (often with Ant),
# because project-specific build logic differs.
#
# Typical output target jar name:
#   defects4j-jars/<PROJECT_ID>/<PROJECT_ID>-b<BUG_ID>.jar
# Example:
#   defects4j-jars/Lang/Lang-b1.jar
#
# Why manual per-project build is still needed
# --------------------------------------------
# Defects4J projects vary in build systems/dependencies. In practice,
# you will need to:
#   - add Checker Framework jars to compilation classpath
# and may need to:
#   - add missing third-party libraries
#   - adjust compiler/source/target flags
#   - skip/ignore failing tests during packaging
#   - tweak project-specific Ant/Maven/Gradle targets
#
# Required environment/tools
# --------------------------
# - defects4j available on PATH
# - checker-framework built under:
#     scripts/build/checker-framework
# - annotation-file-utilities available via CHECKERFRAMEWORK path exports below
#
# Usage
# -----
# 1) Select projects by uncommenting entries in PROJECT_IDS.
# 2) Run:
#      ./buildjars.sh
# 3) For each checked out project under build/defects4j-src/, perform
#    project-specific build + jar packaging manually.
#
# Notes
# -----
# - Logs from infer-and-annotate are stored in:
#     build/defects4j-src/<PROJECT>-<BUG>f/checker.log
# - BUG specs are expanded from ranges like:
#     "1-5,7,10-12"
#===============================================================================

# Environment setup
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"

export CHECKERFRAMEWORK="$SCRIPT_DIR/../scripts/build/checker-framework"
export PATH="$CHECKERFRAMEWORK/annotation-file-utilities/bin:$PATH"
export JAVAC_JAR="$CHECKERFRAMEWORK/checker/dist/javac.jar"

PROJECT_IDS=(
  # Uncomment projects to process.
  # "Chart"
  # "Cli"
  # "Closure"
  # "Codec"
  # "Collections"
  # "Compress"
  # "Csv"
  # "Gson"
  # "JacksonCore"
  # "JacksonDatabind"
  # "JacksonXml"
  # "Jsoup"
  # "JxPath"
  # "Lang"
  # "Math"
  # "Mockito"
  # "Time"
)

# Map each project to bug IDs. Supports comma-separated IDs and ranges.
# Example: "1-26" or "1,3,5-8".
declare -A PROJECT_BUG_SPECS=(
  [Chart]="1-26"
  ["Cli"]="1-5,7-40"
  ["Closure"]="1-62,64-92,94-176"
  ["Codec"]="1-18"
  ["Collections"]="1-28"
  ["Compress"]="1-47"
  ["Csv"]="1-16"
  ["Gson"]="1-18"
  ["JacksonCore"]="1-26"
  ["JacksonDatabind"]="1-64,66-88,90-112"
  ["JacksonXml"]="1-6"
  ["Jsoup"]="1-93"
  ["JxPath"]="1-22"
  ["Lang"]="1,3-17,19-24,26-47,49-65"
  ["Math"]="1-106"
  ["Mockito"]="1-38"
  ["Time"]="1-20,22-27"
)

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------
# Expand bug specs like "1-3,5,7-8" into one BUG_ID per line.
expand_bug_ids() {
  local bug_spec="$1"
  local chunk

  IFS=',' read -r -a chunks <<< "$bug_spec"
  for chunk in "${chunks[@]}"; do
    if [[ "$chunk" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local start="${BASH_REMATCH[1]}"
      local end="${BASH_REMATCH[2]}"
      seq "$start" "$end"
    else
      echo "$chunk"
    fi
  done
}

for PROJECT_ID in "${PROJECT_IDS[@]}"; do
  BUG_SPEC="${PROJECT_BUG_SPECS[$PROJECT_ID]:-}"
  while IFS= read -r BUG_ID; do

    FIXED_WORK_DIR="$SCRIPT_DIR/build/defects4j-src/$PROJECT_ID-${BUG_ID}f"
    rm -rf "$FIXED_WORK_DIR"
    mkdir -p "$FIXED_WORK_DIR"

    LOG_FILE="$FIXED_WORK_DIR/checker.log"

    defects4j checkout -p "$PROJECT_ID" -v "${BUG_ID}f" -w "$FIXED_WORK_DIR"
    SRC_DIR=$(realpath "$FIXED_WORK_DIR/$(defects4j export -p dir.src.classes -w "$FIXED_WORK_DIR")")
    CLASS_DIR=$(defects4j export -p cp.compile -w "$FIXED_WORK_DIR")

    # Run purity inference + annotation over all Java source files.
    # Output is logged to checker.log for diagnostics.
    "$CHECKERFRAMEWORK"/checker/bin/infer-and-annotate.sh \
      org.checkerframework.framework.util.PurityChecker \
      "$CLASS_DIR" \
      "$(find "$SRC_DIR" -name "*.java")" \
      > "$LOG_FILE" 2>&1

    #--------------------------------------------------------------------------
    # Manual project-specific build step (required)
    #--------------------------------------------------------------------------
    # At this point, sources are checked out and annotated.
    # Next, build/package manually for this project+bug:
    #
    #   1) Enter the checked-out project directory:
    #        cd "$FIXED_WORK_DIR"
    #
    #   2) Build using the project's native build flow (often Ant for Defects4J),
    #      ensuring Checker Framework jars are available on classpath.
    #
    #   3) Include additional libs if required by the project.
    #
    #   4) If needed for packaging, skip/ignore failing tests.
    #
    #   5) Package compiled classes into:
    #        $SCRIPT_DIR/<PROJECT_ID>/<PROJECT_ID>-b<BUG_ID>.jar
    #
    # Keep per-project notes/scripts as needed; there is no single universal
    # build command that works for all Defects4J projects.
    #--------------------------------------------------------------------------

  done < <(expand_bug_ids "$BUG_SPEC")
done
