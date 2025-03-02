# Prerequisites for running the mutation script

1. Install *both* Java 8 and Java 11.
   Java 8 should be the default (see the output of `java -version`). The script 
   requires environment variables `JAVA8_HOME` and `JAVA11_HOME` to be set.
   An example way of setting these variables is:
   ```
    export JAVA8_HOME=/usr/lib/jvm/java-8-openjdk-amd64
    export JAVA11_HOME=/usr/lib/jvm/java-11-openjdk-amd64
   ```

2. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   make -C scripts
   ```

3. Use the latest version of Randoop.  (By default, this project uses a released version of Randoop.)

   ```
   make -C scripts randoop-from-source
   ```

4. To get all subject programs, run:
   ```
   cd scripts
   ./get-all-subject-src.sh
   ```
