#!/bin/bash

# For each .jar file in ./libs/, this script:
#  * installs the .jar file into the local Maven repository and
#  * adds it as a dependency to a pom.xml file.

# The path to the lib directory.
LIBS_DIR="build/lib"

# The path to pom.xml.
POM_FILE="program-config/$1/pom.xml"

# Installs necessary packages to maven for all subject programs
mvn install:install-file -Dfile="build/org.jacoco.agent-0.8.0-runtime.jar" -DgroupId="org.jacoco" -DartifactId="org.jacoco.agent" -Dversion="0.8.0" -Dclassifier="runtime" -Dpackaging=jar
mvn install:install-file -Dfile="build/evosuite-standalone-runtime-1.2.0.jar" -DgroupId="org.evosuite" -DartifactId="evosuite-standalone-runtime" -Dversion="1.2.0" -Dpackaging=jar
mvn install:install-file -Dfile="build/junit-4.12.jar" -DgroupId="com.example" -DartifactId="junit" -Dversion="4.12" -Dpackaging=jar
mvn install:install-file -Dfile="build/hamcrest-core-1.3.jar" -DgroupId="com.example" -DartifactId="hamcrest-core" -Dversion="1.3" -Dpackaging=jar

# Backup the pom.xml before modifying it
cp -pf "$POM_FILE" "build/pom.xml.bak"
echo "Backup of pom.xml created at build/pom.xml.bak"

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

  # Check if the dependency is already in the pom.xml
  if grep -q "<artifactId>$artifactId</artifactId>" "$POM_FILE"; then
    echo "Dependency for $artifactId is already in pom.xml. Skipping addition."
  else
    # Create a temporary file for the dependency
    TEMP_FILE=$(mktemp)

    # Create the corresponding <dependency> entry for the pom.xml
    cat << EOF > "$TEMP_FILE"
  <dependency>
    <groupId>$groupId</groupId>
    <artifactId>$artifactId</artifactId>
    <version>$version</version>
EOF

    # Add exclusion if the dependency is log4j-1.2.15
    if [[ "$groupId" == "com.example" && "$artifactId" == "log4j" && "$version" == "1.2.15" ]]; then
      cat << EOF >> "$TEMP_FILE"
    <exclusions>
      <exclusion>
        <groupId>com.sun.jmx</groupId>
        <artifactId>jmxri</artifactId>
      </exclusion>
      <exclusion>
        <groupId>com.sun.jdmk</groupId>
        <artifactId>jmxtools</artifactId>
      </exclusion>
      <exclusion>
        <groupId>javax.jms</groupId>
        <artifactId>jms</artifactId>
      </exclusion>
    </exclusions>
EOF
    fi

    # Close the <dependency> tag
    echo "  </dependency>" >> "$TEMP_FILE"

    # Insert the dependency before the closing </dependencies> tag
    sed -i -e "/<\/dependencies>/r $TEMP_FILE" -e "x; \$ {s/<\/dependencies>//; p; x}; 1d" "$POM_FILE"

    # Clean up the temporary file
    rm -f "$TEMP_FILE"

    echo "Added dependency for $artifactId-$version to pom.xml"
  fi
done

echo "All JARs have been installed and dependencies added to pom.xml."
