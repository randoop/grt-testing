# Prerequisites for running either defect script

1. Java Versions Setup

Defect scripts (via [Defects4J](https://github.com/rjust/defects4j)) require **Java 11** to run correctly.

To allow automatic switching between Java versions, set the following environment variables in your shell configuration file (e.g., `.bashrc`, `.zshrc`, or `.bash_profile`):

```sh
export JAVA8_HOME=/path/to/your/java8
export JAVA11_HOME=/path/to/your/java11
```

2. Required tools:

   * **Git** ≥ 1.9

   * **Subversion (svn)** ≥ 1.8

   * **Perl** ≥ 5.12

   * **cpanm** (Perl module installer)

   > `cpanm` is required to install Perl dependencies used by Defects4J.
   > Install it using the following command:
   >
   > ```sh
   > curl -L https://cpanmin.us | perl - App::cpanminus
   > ```

3. Obtain Defects4J, the tools, and dependencies:
   ```sh
   make -C scripts
   ```

4. If using Randoop, use the development version (the latest commit) rather than a released version. Skip this step if only using EvoSuite.

   ```sh
   make -C scripts randoop-from-source
   ```

5. Add Defects4J's executables to your PATH (shell session where you run the defect scripts):
    ```sh
    export PATH=$PATH:"path2defects4j"/framework/bin
    ```
   ("path2defects4j" points to the directory which Defects4J is in; it most likely will look like "currentdirectory/build/defects4j".)
