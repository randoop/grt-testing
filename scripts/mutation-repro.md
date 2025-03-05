# Reproduction Instructions for Mutation Testing Script

This document describes how to run the mutation testing script `mutation.sh`.


## Prerequisites

See [mutation-prerequisites.md].


## Running the mutation test script

Parameters:
    - `-v`: Enables verbose mode
    - `-r`: Redirect Randoop and Major output to `results/result/mutation_output.txt`
    - `-t`: Specifies the total time limit for Randoop to generate tests (in seconds)
    - `-c`: Specifies the time limit for Randoop to generate tests per class (in seconds, defaults to 2s/c), mutually exclusive with `-t`
    - `[subject project]`: The name of the subject program for which you want to generate tests
    and perform mutation testing. The name is one of the jar files in `../subject-programs/`, without ".jar".
    For example, to run the script on the `commons-lang3-3.0` project, with verbose output and output directed to a file, you would run:

    ./mutation.sh -vr commons-lang3-3.0

3. **Output**:
The script will generate Randoop's test suites in a `scripts/build/test` subdirectory.
Compiled tests and code will be stored in `scripts/build/bin` subdirectory.
The `results/` directory contains the results of coverage and mutation analysis.
See `results/info.txt` for a summary of coverage and mutation scores from previous runs.


## Randoop version

**NOTE**: For Demand-driven (PR #1260), GRT Fuzzing (PR #1304), and Elephant Brain (PR #1347),
checkout the respective pull requests from the Randoop repository and build the
project.
