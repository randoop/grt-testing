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

# Loop through each JAR file in the libs directory
for jar in "$LIBS_DIR"/*.jar; do
    # Get the base filename without path
    filename=$(basename "$jar")
    
    # Remove the .jar extension to get artifactId-version
    name_version="${filename%.*}"
    
    # Split the name_version into artifactId and version
    artifactId=$(echo "$name_version" | cut -d'-' -f1)
    version=$(echo "$name_version" | cut -d'-' -f2-)

    # Define the groupId (you can modify this as needed)
    groupId="com.example"  # Change this if needed

    # Install the JAR file into the local Maven repository
    mvn install:install-file -Dfile="$jar" -DgroupId="$groupId" -DartifactId="$artifactId" -Dversion="$version" -Dpackaging=jar
    echo "Installed $filename into local Maven repository"

    # Create the corresponding <dependency> entry for the pom.xml
    dependency="<dependency><groupId>$groupId</groupId><artifactId>$artifactId</artifactId><version>$version</version></dependency>"

    # Add the dependency entry to pom.xml (inside <dependencies> section)
    # This will append the dependency just before the closing </dependencies> tag
    sed -i "/<\/dependencies>/i $dependency" "$POM_FILE"
    echo "Added dependency for $artifactId-$version to pom.xml"
done

# Print the final message
echo "All JARs have been installed and dependencies added to pom.xml."
