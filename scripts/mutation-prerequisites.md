# Prerequisites for running the mutation script

1. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   make -C scripts
   ```

2. Use the latest version of Randoop. \
   Use **Java 11** to run the following command:

   ```
   make -C scripts randoop-from-source
   ```
   Switch back to **Java 8** to run the mutation script.


3. To get all subject programs, run:
   ```
   cd scripts
   ./get-all-subject-src.sh
   ```
