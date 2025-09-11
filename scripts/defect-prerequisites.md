# Prerequisites for running either defect script

1. Make sure you are using Java 11

2. Obtain Defects4J, the tools, and dependencies:
   ```sh
   make -C scripts
   ```

3. If using Randoop, use the development version (the latest commit) rather than a released version. Skip this step if only using EvoSuite.

   ```sh
   make -C scripts randoop-from-source
   ```

4. Add Defects4J's executables to your PATH:
    ```sh
    export PATH=$PATH:"path2defects4j"/framework/bin
    ```
   ("path2defects4j" points to the directory which Defects4J is in; it most likely will look like "currentdirectory/build/defects4j".)
