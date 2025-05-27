# Test cases and scripts for testing Randoop and EvoSuite

## Overview

This repository contains test cases and scripts designed for testing
[Randoop](https://github.com/randoop/randoop) and
[EvoSuite](https://www.evosuite.org/),
specifically for comparison with
the results presented in the paper "[GRT: Program-Analysis-Guided Random
Testing](GRT_Program-Analysis-Guided_Random_Testing.pdf)"

## Usage Instructions

### Setup
To set up the environment, refer to the `scripts/mutation-prerequisites.md` file.

### Running Scripts
For prerequisities, refer to `scripts/mutation-prerequisities.md`.
For instructions on using the scripts, refer to `scripts/mutation-randoop.sh` for Randoop and `scripts/mutation-evosuite.sh` for EvoSuite.

### Running GRT Experiments
See file `scripts/experiment-scripts/README.md`.

### Subject Programs

The compiled subject programs used by the GRT paper appear in the `subject-programs/` directory.

To obtain the sources of the subject programs, see
`subject-programs/README.build`.
