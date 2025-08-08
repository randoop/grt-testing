# Scripts for Running GRT Experiments

## Overview

This folder contains scripts designed for running the GRT experiments as presented in the paper
"[GRT: Program-Analysis-Guided Random Testing](GRT_Program-Analysis-Guided_Random_Testing.pdf)"

These scripts automate the execution of various configurations of the `mutation-randoop.sh` and `mutation-evosuite.sh` driver scripts, collect results, and generate the corresponding figures and tables used in the evaluation.

### Setup
To set up the environment, refer to the `scripts/mutation-prerequisites.md` file.

### Running Scripts

To generate the desired figures or tables from the paper, run the corresponding shell script. For example, to generate **Figure 7**, use:

```bash
./mutation-fig7.sh
```

Each script is documented at the top of the file with:
- What it generates (figure/table)
- What input parameters or configuration it expects
- What output files it will produce and where

### Output

Each experiment script writes its output to the `results/` directory. This includes:

`results/[experiment].csv`: the raw collected data from multiple `mutation-randoop.sh` and/or `mutation-evosuite.sh` runs.
`results/[experiment].pdf`: the final rendered figure(s) and/or table(s) for the experiment.

**Note:** Running an experiment script will overwrite any existing results for
that specific experiment, but will not overwrite results for other scripts.  To
preserve existing results, be sure to copy or download them before rerunning the
same script.
