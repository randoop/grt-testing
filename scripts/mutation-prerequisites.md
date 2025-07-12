# Prerequisites for running either mutation script

1. Obtain the mutation programs, some dependencies, and the source code for the subject programs:
   ```
   make -C scripts
   ```

2. If using Randoop, use the development version (the latest commit) rather than a released version. Skip this step if only using EvoSuite.

   ```
   make -C scripts randoop-from-source
   ```

3. To get all subject programs, run:
   ```
   cd scripts
   ./get-all-subject-src.sh
   ```
