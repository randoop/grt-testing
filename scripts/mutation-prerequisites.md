# Prerequisites for running either mutation script

1. Java Versions Setup

   Mutation scripts (via [Major](https://github.com/rjust/major)) require **Java
   8** to run correctly.

   To allow automatic switching between Java versions, set the following
   environment variables in your shell configuration file (e.g., `.bashrc`,
   `.zshrc`, or `.bash_profile`):

   ```sh
   export JAVA8_HOME=/path/to/your/java8
   export JAVA11_HOME=/path/to/your/java11
   ```

2. Obtain the mutation programs, some dependencies, and the source code for the
   subject programs:

   ```sh
   make -C scripts
   ```

3. If using Randoop, use the development version (the latest commit) rather than
   a released version. Skip this step if only using EvoSuite.

   ```sh
   make -C scripts randoop-from-source
   ```

4. To get all subject programs, run:

   ```sh
   cd scripts
   ./get-all-subject-src.sh
   ```
