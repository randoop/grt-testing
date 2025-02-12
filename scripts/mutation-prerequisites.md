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
   cd scripts
   make
   ```

3. Clone the Randoop repository from GitHub. After cloning, go to the Randoop directory and build the
   project. You can do this by running:
   ```
   usejdk11
   cd build
   git clone git@github.com:randoop/randoop.git
   cd randoop
   ./gradlew shadowJar
   mv -f build/libs/randoop-all-4.3.3.jar agent/replacecall/build/libs/replacecall-4.3.3.jar ../../build
   usejdk8
   ```
   You may delete the Randoop repository after the above instructions.

4. To get all subject programs, run:
   ```
   cd ../..
   ./get-all-subject-src.sh
   ```
