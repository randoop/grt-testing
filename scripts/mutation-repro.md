# Reproduction Instructions for Mutation Testing Script

This document describes how to run the mutation testing script ([mutation.sh]).
You can also run `mutation-all.sh`
to run `mutation.sh` on all the subject programs.


## Prerequisites

See [mutation-prerequisites.md].


## Running the mutation test script

Parameters:
    - `-v`: Enables verbose mode
    - `-r`: Redirect Randoop and Major output to `results/result/mutation_output.txt`
    - `-t`: Specifies the total time limit for Randoop to generate tests (in seconds)
    - `-c`: Specifies the time limit for Randoop to generate tests per class (in seconds), mutually exclusive with `-t`
    - `[subject project]`: The name of the subject program for which you want to generate tests
    and perform mutation testing. The name is one of the jar files in `../subject-programs/`, without ".jar".

    For example, to run the script on the `commons-lang3-3.0` project, with verbose output and output directed to a file, you would run:
    ```
    ./mutation.sh -vr commons-lang3-3.0
    ```

3. **Output**:
The script will generate Randoop's test suites in a "build/test"
subdirectory. The result subdirectory for a specific run under 'results' also
contains a copy of the test suites. Compiled tests and code will be stored in a
"build/bin" subdirectory. The script will generate various mutants of the source
project using Major and run these tests on those mutants. Each experiment can
run a given number of times and a given number of seconds per class. Various
statistics of each iteration will be logged to a file "results/info.txt".


## Randoop version

**NOTE**: For Demand-driven (PR #1260), GRT Fuzzing (PR #1304), and Elephant Brain (PR #1347),
checkout the respective pull requests from the Randoop repository and build the
project.
