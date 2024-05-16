#!/bin/sh

MAJOR_HOME="../../"

echo "- Running javac without the mutation plugin"
echo "  (javac triangle/Triangle.java)"
javac triangle/Triangle.java

echo
echo "- Running javac (major wrapper) with the mutation plugin"
echo "  (\$MAJOR_HOME/bin/major --mml \$MAJOR_HOME/mml/tutorial.mml.bin triangle/Triangle.java)"
$MAJOR_HOME/bin/major --mml $MAJOR_HOME/mml/tutorial.mml.bin triangle/Triangle.java

echo
echo "- Compiling test case (config.jar has to be on the classpath!)"
echo "  (javac -cp .:\$MAJOR_HOME/config/config.jar TriangleTest.java)"
javac -cp .:$MAJOR_HOME/config/config.jar TriangleTest.java

echo
echo "- Executing test case (config.jar has to be on the classpath!)"
echo "  (java -cp .:\$MAJOR_HOME/config/config.jar TriangleTest)"
echo
java -cp .:$MAJOR_HOME/config/config.jar TriangleTest
