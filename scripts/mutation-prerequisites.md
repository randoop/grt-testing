# Prerequisites for running either mutation script

1. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   make -C scripts
   ```

2. If using Randoop, use the latest version. Feel free to skip this step if using EvoSuite.

   ```
   make -C scripts randoop-from-source
   ```

3. To get all subject programs, run:
   ```
   cd scripts
   ./get-all-subject-src.sh
   ```
