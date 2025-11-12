# Test cases and scripts for testing Randoop and EvoSuite

## Overview

This repository contains test cases and scripts designed for testing
[Randoop](https://github.com/randoop/randoop) and
[EvoSuite](https://www.evosuite.org/),
specifically for comparison with
the results presented in the paper "[GRT: Program-Analysis-Guided Random
Testing](GRT_Program-Analysis-Guided_Random_Testing.pdf)"

The GRT paper uses two methods of evaluation:

1. **Mutation analysis** measures how well generated tests kill artificially
  seeded faults (mutants).
2. **Defect detection** measures the ability of generated tests to detect
  known real-world defects.

This repository provides scripts and setup files for running both kinds of evaluation.

## Usage Instructions

### Setup

To set up the environment, refer to the `scripts/prerequisites.md` file.

### Running Scripts

For mutation analysis see:

* `scripts/mutation-randoop.sh` for Randoop
* `scripts/mutation-evosuite.sh` for EvoSuite

For defect detection see:

* `scripts/defects4j-randoop.sh` for Randoop
* `scripts/defects4j-evosuite.sh` for EvoSuite

### Running GRT Experiments

See file `scripts/experiment-scripts/README.md`.

### Subject Programs

The compiled subject programs used by the GRT paper appear in the
`subject-programs/` directory.

To obtain the sources of the subject programs, see
`subject-programs/README.build`.
