#!/bin/bash

# For each .jar file in build/lib/, this script:
#  * installs the .jar file into the local Maven repository

# The path to the lib directory.
LIBS_DIR="build/lib"

# Installs necessary packages to maven for all subject programs
mvn install:install-file -Dfile="build/org.jacoco.agent-0.8.0-runtime.jar" -DgroupId="org.jacoco" -DartifactId="org.jacoco.agent" -Dversion="0.8.0" -Dclassifier="runtime" -Dpackaging=jar
mvn install:install-file -Dfile="build/evosuite-standalone-runtime-1.2.0.jar" -DgroupId="org.evosuite" -DartifactId="evosuite-standalone-runtime" -Dversion="1.2.0" -Dpackaging=jar
mvn install:install-file -Dfile="build/junit-4.12.jar" -DgroupId="com.example" -DartifactId="junit" -Dversion="4.12" -Dpackaging=jar
mvn install:install-file -Dfile="build/hamcrest-core-1.3.jar" -DgroupId="com.example" -DartifactId="hamcrest-core" -Dversion="1.3" -Dpackaging=jar

if ! find "$LIBS_DIR" -maxdepth 1 -name '*.jar' | grep -q .; then
  echo "No JAR files found in $LIBS_DIR. Skipping."
  exit 0
fi

for jar in "$LIBS_DIR"/*.jar; do
  # Get the base filename without path
  filename=$(basename "$jar")
  base="${filename%.*}"

  # Extract artifactID and version from the dependency
  # Assuming the version is the part after the last '-' in the filename
  groupId="com.example"
  artifactId="${base%-*}"
  version="${base##*-}"

  # Install the JAR file into the local Maven repository
  mvn install:install-file -Dfile="$jar" -DgroupId="$groupId" -DartifactId="$artifactId" -Dversion="$version" -Dpackaging=jar
  echo "Installed $filename into local Maven repository"

done

echo "All JARs have been installed to the local maven repository."
