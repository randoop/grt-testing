# Test cases and scripts for testing Randoop

## Overview

This repository contains test cases and scripts designed for testing
[Randoop](https://github.com/randoop/randoop), specifically for comparison with
the results presented in the paper "[GRT: Program-Analysis-Guided Random
Testing](GRT_Program-Analysis-Guided_Random_Testing.pdf)"

## Usage Instructions

### Setup
To set up the environment, refer to the `scripts/mutation-prerequisites.md` file.

### Running Scripts
For instructions on using the scripts, run the following command:

```bash
./scripts/mutation.sh -h
```

### Running Experiments
For running experiments, refer to the `scripts/mutation-parallel.sh` file.

### Subject Programs

The compiled subject programs used by the GRT paper appear in the `subject-programs/` directory.

To obtain the sources of the subject programs, see
`subject-programs/README.build`.
