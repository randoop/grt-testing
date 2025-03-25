# Reproduction Instructions for EvoSuite Mutation Testing Script

This document describes how to run the
EvoSuite mutation testing script ([mutation-evosuite.sh]).

## Prerequisites

See [mutation-prerequisites.md].


## Running the mutation test script

Parameters:
    - `-v`: Enables verbose mode
    - `-r`: Redirect test generation and Major output to `results/result/mutation_output.txt`
    - `-t`: Specifies the total time limit for test generation (in seconds)
    - `-c`: Specifies the time limit for test generation per class (in seconds, defaults to 2s/c), mutually exclusive with `-t`
    - `[subject project]`: The name of the subject program for which you want to generate tests
    and perform mutation testing. The name is one of the jar files in `../subject-programs/`, without ".jar".

    For example, to run the script on the `commons-lang3-3.0` project, with verbose output and output directed to a file, you would run:
    ```
    ./mutation-evosuite.sh -vr commons-lang3-3.0
    ```

3. **Output**:
The script generates test suites in a
`evosuite-tests/` directory. 
Compiled code
for Major will be stored in the `build/bin` directory. A `target` subdirectory (containing compiled subject program 
source code and compiled evosuite test files) will be generated for the purpose of measuring code coverage (via Jacoco). Finally, a `libs` directory is created to hold the JAR file dependencies, which are installed to Maven's local repository.
The `results/` directory contains the results of coverage and mutation analysis.
See `results/info.csv` for a summary of coverage and mutation scores from previous runs.

For EvoSuite, most subject programs should have very few tests that fail with ant (for Major), with maven (for Jacoco), or both. 
Subject programs that have a considerable number of flaky tests (40-50 methods) are: javassist-3.19, sat4j-core-2.3.5, and slf4j-api-1.7.12. 
The reasons for these flaky tests are out of our control (issues with EvoSuite, limitations with Major, etc.). If you are experiencing subject 
programs other than these  listed above that have a lot of flaky tests, then something is most likely wrong -- please file an issue.
