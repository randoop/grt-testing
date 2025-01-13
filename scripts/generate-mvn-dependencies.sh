#!/bin/bash

# Set the path to your libs directory
LIBS_DIR="./libs"

# Path to your pom.xml
POM_FILE="./pom.xml"

# Check if pom.xml exists
if [ ! -f "$POM_FILE" ]; then
    echo "pom.xml not found in the current directory. Exiting."
    exit 1
fi

# Backup the pom.xml before modifying it
cp "$POM_FILE" "$POM_FILE.bak"
echo "Backup of pom.xml created at $POM_FILE.bak"

# Define mappings from jar filenames to groupId and artifactId
declare -A groupIdMap
declare -A artifactIdMap

# Map known jars to their correct groupId and artifactId
groupIdMap["junit-4.12.jar"]="junit"
artifactIdMap["junit-4.12.jar"]="junit"

groupIdMap["hamcrest-core-1.3.jar"]="org.hamcrest"
artifactIdMap["hamcrest-core-1.3.jar"]="hamcrest-core"

groupIdMap["log4j-1.2.17.jar"]="log4j"
artifactIdMap["log4j-1.2.17.jar"]="log4j"

groupIdMap["evosuite-standalone-runtime-1.2.0.jar"]="org.evosuite"
artifactIdMap["evosuite-standalone-runtime-1.2.0.jar"]="evosuite-standalone-runtime"

# You can add more mappings as needed

# Loop through each JAR file in the libs directory
for jar in "$LIBS_DIR"/*.jar; do
    # Get the base filename without path
    filename=$(basename "$jar")

    # Check if the filename is in the mapping
    if [[ -n "${groupIdMap[$filename]}" ]]; then
        groupId="${groupIdMap[$filename]}"
        artifactId="${artifactIdMap[$filename]}"
    else
        groupId="com.example"
        artifactId="${filename%.*}"
    fi

    # Extract the version from the filename
    # Assuming the version is the part after the last '-' in the filename
    baseName="${filename%.*}"
    version="${baseName##*-}"

    # Install the JAR file into the local Maven repository
    mvn install:install-file -Dfile="$jar" -DgroupId="$groupId" -DartifactId="$artifactId" -Dversion="$version" -Dpackaging=jar
    echo "Installed $filename into local Maven repository"

    # Check if the dependency is already in the pom.xml
    if grep -q "<artifactId>$artifactId</artifactId>" "$POM_FILE"; then
        echo "Dependency for $artifactId is already in pom.xml. Skipping addition."
    else
        # Create the corresponding <dependency> entry for the pom.xml
        dependency="  <dependency>\n    <groupId>$groupId</groupId>\n    <artifactId>$artifactId</artifactId>\n    <version>$version</version>\n"

        # Add exclusion if the dependency is log4j-1.2.15
        if [[ "$groupId" == "com.example" && "$artifactId" == "log4j-1.2.15" && "$version" == "1.2.15" ]]; then
            exclusion="<exclusions>\n      <exclusion>\n        <groupId>com.sun.jmx</groupId>\n        <artifactId>jmxri</artifactId>\n      </exclusion>\n      <exclusion>\n        <groupId>com.sun.jdmk</groupId>\n        <artifactId>jmxtools</artifactId>\n      </exclusion>\n      <exclusion>\n        <groupId>javax.jms</groupId>\n        <artifactId>jms</artifactId>\n      </exclusion>\n  </exclusions>"

            # Append the exclusion to the dependency
            dependency="$dependency$exclusion"
        fi

        # Close the <dependency> tag
        dependency="$dependency\n  </dependency>"

        # Add the dependency entry to pom.xml (inside <dependencies> section)
        # This will append the dependency just before the closing </dependencies> tag
        sed -i "/<\/dependencies>/i $dependency" "$POM_FILE"
        echo "Added dependency for $artifactId-$version to pom.xml"
    fi
done

# Print the final message
echo "All JARs have been installed and dependencies added to pom.xml."
