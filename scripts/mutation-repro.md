# Reproduction Instructions for Mutation Testing Script

This document describes how to run the mutation testing script `mutation.sh`.


## Prerequisites

See [mutation-prerequisites.md].


## Running the mutation test script

Parameters:
- `<subject-jar>`: The path to the subject program jar file.
- `<java-src-dir>`: The path to the Java source directory used for mutation generation and analysis. Located in the `subject-programs/src` directory.
- `<lib-dir>`: The directory containing additional jar files (dependencies) used during compilation (e.g., for Ant's -lib option).

    For example, to run the script on the subject program `a4j-1.0b`:
    ```
    ./mutation.sh a4j-1.0b ../subject-programs/src/a4j-1.0b/src/ ../subject-programs/src/a4j-1.0b/jars/
    ```

3. **Output**:
The script will generate Randoop's test suites in a `scripts/build/test` subdirectory.
Compiled tests and code will be stored in `scripts/build/bin` subdirectory.
The `results/` directory contains the results of coverage and mutation analysis.
See `results/info.txt` for a summary of coverage and mutation scores from previous runs.


## Randoop version

**NOTE**: For Demand-driven (PR #1260), GRT Fuzzing (PR #1304), and Elephant Brain (PR #1347),
checkout the respective pull requests from the Randoop repository and build the
project.
