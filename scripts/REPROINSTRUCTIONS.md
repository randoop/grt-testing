# Reproduction Instructions for Mutation Testing Script

This section provides detailed instructions on how to run the mutation testing script.
 
Please follow these steps:

1. **Running the Script**: Navigate to the `grt-testing/scripts` directory. Then, run the shell script of the project of your choosing: (e.g. ``` ./commons-cli-1.2.sh ```)

2. **Setting Variables**: Each experiment can run a given number of times and a given number of seconds per class, which you can change using the NUM_LOOP and SECONDS_CLASS variables in `mutation.sh`

---------------------------------------------------------------------------------------------------
# How it Works

This section provides information on what to expect when using this script.

1. **Makefile**: The script initially runs make, after which two subdirectories are created: build and results. The build subdirectory contains `major/` (Major), `randoop-all-4.3.2.jar` (the jarfile for Randoop), `jacocoagent.jar` (the jarfile for the Jacoco Agent, which is used to track coverage), and `javaparser-core-3.25.10.jar` (used to compile MethodExtractor.java). The results subdirectory is initially empty.

2. **git**: The script then attempts to clone the source code for the associated project into `grt-testing/tests/src` using git. If it already exists, it skips this step. As discussed below, build.xml and mutation.sh use this source code to generate mutants.

3. **Calling mutation.sh**: Each script then calls mutation.sh, passing in the jarfile for the associated project and the directory containing the project's source code. Any other jarfiles required for source code compilation are also passed into mutation.sh 

4. **Mutation.sh**: The script first uses a particular version of Randoop to generate tests on the 
given jarfile name. It puts these tests in the directory `build/test*`. Then, it invokes
the clean and compile targets in `build.xml`. Given the path to the project's Java source code, these
targets use Major to generate mutants and put them in the directory `build/bin`. Next, it invokes the
compile.tests target to compile all of the Randoop-generated tests and also puts them in the directory
`build/bin`. Finally, it invokes the mutation.test target which runs the mutation analysis on all
the mutants using the test suite.

5. **MethodExtractor.java**: The script calls MethodExtractor.java immediately after Randoop generates a test suite. 
MethodExtractor.java takes a test suite as input and removes any methods in the test suite that fail in isolation.
I added this step in the pipeline because Major appears to run the tests in the test suite in isolation.

6. **build.xml**: The build.xml is used by mutation.sh to generate mutants using Major and run 
Randoop-generated tests on those mutants. More information about each target can be found
in the build.xml file.

7. **Output**: After every iteration of the experiment, a summary of the results are appended to a file
"results/info.txt".

---------------------------------------------------------------------------------------------------
# Additional Notes

1. The latest release of Randoop does not implement functionality for Orienteering. 
If you wish to work with Orienteering, you should download and build Randoop from Github and 
replace $RANDOOP_JAR with the absolute path.

2. You must have JDK 8 as your default java/javac for Major to work.

3. Right now, ClassViewer-5.0.5b.sh is not working. I am only including it in this repository for debugging purposes
(I am trying to figure out why some tests in the Randoop-generated test suite throw an AssertionFailedError when
used by Major).
