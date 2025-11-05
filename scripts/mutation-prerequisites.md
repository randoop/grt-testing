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

2. Obtain dependencies and subject programs:

   ```sh
   make -C scripts
   make -C scripts randoop-from-source
   cd scripts
   ./get-all-subject-src.sh
   ```
