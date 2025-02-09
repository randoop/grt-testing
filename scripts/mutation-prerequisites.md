# Prerequisites for running the mutation script

1. Install *both* Java 8 and Java 11.
   Java 8 should be the default (see the output of `java -version`), and 
   environment variable `JAVA_HOME` should be set; for example:
   ```
   export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
   ```

2. Define two scripts or aliases `usejdk8` and `usejdk11` that switch
   between Java 8 and Java 11.

   Many implementations of `usejdk8` and `usejdk11` are possible.
   One way is to make JAVA_HOME refer
   to a symbolic link, and put $JAVA_HOME/bin on your PATH.  Then, the two
   scripts just change the symbolic link.
   ```
   # $HOME/java/jdk8 and $HOME/java/jdk11 exist, and
   # $HOME/java/jdk is a symbolic link to one of them.
   export JAVA_HOME=$HOME/java/jdk
   alias usejdk8='(cd ~/java && rm -f jdk && ln -s jdk8 jdk)'
   alias usejdk11='(cd ~/java && rm -f jdk && ln -s jdk11 jdk)'
   ```

3. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   cd scripts
   make
   ```

4. Clone the Randoop repository from GitHub. After cloning, go to the Randoop directory and build the
   project. You can do this by running:
   ```
   usejdk11
   cd build
   git clone git@github.com:randoop/randoop.git
   cd randoop
   ./gradlew shadowJar
   mv -f build/libs/randoop-all-4.3.3.jar build/libs/replacecall-4.3.3.jar ../build/
   usejdk8
   ```
   You may delete the Randoop repository after the above instructions.

5. To get all subject programs, run:
   ```
   cd ../..
   ./get-all-subject-src.sh
   ```
