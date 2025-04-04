# Prerequisites for running the mutation script

1. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   make -C scripts
   ```

2. Use the latest version of Randoop.

   ```
   make -C scripts randoop-from-source
   ```

3. To get all subject programs, run:
   ```
   cd scripts
   ./get-all-subject-src.sh
   ```
