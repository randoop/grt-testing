# Scripts for Running GRT Experiments

## Overview

This folder contains scripts designed for running the GRT experiments as
presented in the paper "[GRT: Program-Analysis-Guided Random
Testing](GRT_Program-Analysis-Guided_Random_Testing.pdf)"

These scripts execute various configurations of the mutation analysis and defect
detection driver scripts, collect results, and generate the corresponding
figures and tables.

## Setup

To set up the environment, refer to the `scripts/prerequisites.md` file.

### Running Scripts

To generate the desired figures or tables from the paper, run the corresponding
shell script, from this directory.

```sh
./defects4j-table4.sh
./mutation-fig6-table3.sh
./mutation-fig7.sh
./mutation-fig8-9.sh
```

Each script is documented at the top of its file with:

* What it generates (figure/table)
* What input parameters or configuration it expects
* What output files it will produce and where

## Output

Each experiment script writes its output to the `results/` directory. This includes:

* `results/[experiment].csv`: the raw collected data from multiple
  `mutation-randoop.sh` and/or `mutation-evosuite.sh` runs.
* `results/[experiment].pdf`: the final rendered figure(s) and/or table(s) for
  the experiment.

**Note:** Running an experiment script will overwrite any existing results for
that specific experiment, but will not overwrite results for other scripts.  To
preserve existing results, be sure to copy or download them before rerunning the
same script.
