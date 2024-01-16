# Reproduction Instructions for Mutation Testing Script

This section provides detailed instructions on how to run the mutation testing script.
 
Please follow these steps:

1. **Run Make**: Navigate to the directory containing the script and Makefile and run the following:
    ``` make ```. More information on what make does can be found in the section
    "What to Expect"

2. **Running the Script**: Then, run the following command: 
    ``` ./mutation.sh [jarfile name] [Linux directory of project's Java source code] ```
    - `[jarfile name]`: The name of the jar file of the project for which you to perform
    mutation testing. This should be one of the jarfiles in the `grt-testing/tests` subdirectory 
    (e.g. `commons-cli-1.2.jar`)
    - `[Linux directory of project's Java source code]`: The Linux directory where that project's
    Java source code is located. This should be a path to one of the projects in the `grt-testing/tests/src`
    subdirectory (e.g. if you are in the `grt-testing/scripts` directory, `../tests/src/commons-cli-1.2-src` 
    would be valid path).

3. **Setting Variables**: Each experiment can run a given number of times and a given number of seconds per class,
which you can change using the NUM_LOOP and SECONDS_CLASS variables in `mutation.sh`

---------------------------------------------------------------------------------------------------
# How it Works

This section provides information on what to expect when using this script.

1. **Makefile**: After running make, two subdirectories are created: build and results. The build 
subdirectory contains `major/` (Major), `randoop-all-4.3.2.jar` (the jarfile for Randoop), and 
`jacocoagent.jar` (the jarfile for the Jacoco Agent, which is used to track coverage). The results 
subdirectory is initially empty.

2. **build.xml**: The build.xml is used by mutation.sh to generate mutants using Major and run 
Randoop-generated tests on those mutants. More information about each target can be found
in the build.xml file.

3. **Mutation.sh**: The script first uses a particular version of Randoop to generate tests on the 
given jarfile name. It puts these tests in the directory `build/test*`. Then, it invokes
the clean and compile targets in `build.xml`. Given the path to the project's Java source code, these
targets use Major to generate mutants and put them in the directory `build/bin`. Next, it invokes the
compile.tests target to compile all of the Randoop-generated tests and also puts them in the directory
`build/bin`. Finally, it invokes the mutation.test target which runs the mutation analysis on all
the mutants using the test suite. 

4. **Output**: After every iteration of the experiment, a summary of the results are appended to a file
"results/info.txt". The other files generated are statistics for the most recent run of the experiment,
so ignore those.

---------------------------------------------------------------------------------------------------
# Additional Notes

1. The latest release of Randoop does not implement functionality for Orienteering. 
If you wish to work with Orienteering, you should download and build Randoop from Github and 
replace $RANDOOP_JAR with the absolute path.

2. You must have JDK 8 as your default java/javac for Major to work.
