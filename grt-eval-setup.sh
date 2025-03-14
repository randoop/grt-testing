#!/bin/bash

################################################################################
#
# This script sets up grt-eval.sh. It addresses java versioning
#
################################################################################

# Setup java 8 and java 11: Replace with latest versions as needed
cd ~
wget https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u292-b10_openj9-0.26.0/OpenJDK8U-jdk_x64_linux_openj9_8u292b10_openj9-0.26.0.tar.gz
wget https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz

mkdir ~/java
tar -xvzf OpenJDK8U-jdk_x64_linux_openj9_8u292b10_openj9-0.26.0.tar.gz -C ~/java
tar -xvzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz -C ~/java

# You can also add this to your .bashrc
alias usejdk8='export JAVA_HOME=~/java/jdk8u292-b10 && export PATH=$JAVA_HOME/bin:$PATH'
alias usejdk11='export JAVA_HOME=~/java/jdk-11.0.9.1+1 && export PATH=$JAVA_HOME/bin:$PATH'

# Setup grt-testing
cd grt-testing # or where your defects4j-grt directory is

./grt-eval.sh
# nohup ./grt-eval.sh --ignore-warning &