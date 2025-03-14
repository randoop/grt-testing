#!/bin/bash

################################################################################
#
# This script runs Coverage and Mutation Score computation in parallel. It 
# handles setup (excluding mutations-specific setup), which you should do from 
# the scripts/mutation-prerequisites.md of this repo).
# The command should be run from the root directory of `grt-testing`.
# 
# Use ./grt-eval.sh --ignore-warning to bypass the user check
# This can be useful when making this a background process.
# 
# If there are java versions missing, see grt-eval-setup.sh
#
################################################################################

# Function to prompt the user for confirmation
confirm_proceed() {
    while true; do
        read -p "Type 'y' to continue: " response
        case $response in
            [Yy]* )
                echo "Proceeding with the action."
                return 0  # Success, proceed with the action
                ;;
            [Nn]* )
                echo "Action aborted."
                return 1  # Exit or abort, action canceled
                ;;
            * )
                echo "Invalid input. Please type 'y' to proceed or 'n' to cancel."
                ;;
        esac
    done
}

# Functions to switch jdk version
usejdk8() {
    export JAVA_HOME=~/java/jdk8u292-b10
    export PATH=$JAVA_HOME/bin:$PATH
}
usejdk11() {
    export JAVA_HOME=~/java/jdk-11.0.9.1+1
    export PATH=$JAVA_HOME/bin:$PATH
}

# Warn about files removed
echo "Warning: This script will REMOVE all grt-testing/scripts/results directories and grt-testing/scripts/mutation_output.txt!"
echo "Are you sure you want to proceed? (y/n)"
if [[ "$1" == "--ignore-warning" ]] || confirm_proceed; then
  echo "Running script..."
else
  exit 1
fi

cd ..
WORK_DIR=$(pwd)
export randoop=$WORK_DIR/"randoop-grt"

# Setup grt-testing
echo "START: Setting up grt-testing and randoop-grt"

cd grt-testing/scripts
make

# Setup randoop-grt
cd $WORK_DIR
if [ ! -d "randoop-grt" ]; then
    git clone git@github.com:edward-qin/randoop-grt.git randoop-grt
fi
cd randoop

usejdk11
./gradlew shadowJar
mv -f build/libs/randoop-all-4.3.3.jar agent/replacecall/build/libs/replacecall-4.3.3.jar $WORK_DIR/"grt-testing/scripts/build"

cd $WORK_DIR/"grt-testing/scripts"
./get-all-subject-src.sh
echo "SUCCESS: Set up grt-testing and randoop-grt"

# Run grt generation in parallel
echo "START: Running Coverage and Mutation Score Computation"

rm -rf results
rm mutation_output.txt

usejdk8
./mutation-fig6-parallel.sh
echo "SUCCESS: Ran Coverage and Mutation Score Computation"

# Create table with python file
echo "START: Generating Table IV from results"

python -m venv $WORK_DIR/"grt-testing/.venv"
source  $WORK_DIR/"grt-testing/.venv/bin/activate"
pip install pandas

python generate_fig6_tab3.py
echo "SUCCESS: Generated Figure 6 and Table III from results"

exit 0