# Annotated Subject Program JARs

This folder holds subject `.jar` files with purity annotations:  `@Pure`,
`@SideEffectFree`, `@Impure`, and related qualifiers from
`org.checkerframework.framework.qual` Compared to `subject-programs/jars/`, the
compiled bytecode here is the same, but the class files have purity
annotations. No other code or resources are altered.

The annotations are produced by the Checker Framework whole-program inference.

## Why the annotations matter

The `GRT_FUZZING` feature in `scripts/mutation-randoop.sh` prioritizes impure
calls to mutate an object's state before exercising additional API entry points.
The annotations provide the information it needs.

## Rebuilding an annotated JAR

### Setup

1. **Fetch sources**: From the top level (`../../`), run
   `scripts/get-all-subject-src.sh` to populate
   `subject-programs/src/<subject-program>/`.

2. **Set up inference tooling**: Point your environment at the local Checker
   Framework build:

   ```sh
   export CHECKERFRAMEWORK=/path/to/grt-testing/scripts/build/checker-framework
   export PATH="$CHECKERFRAMEWORK/annotation-file-utilities/bin:$PATH"
   ```

3. **Build the plain JAR**: Run `subject-programs/buildall.sh`.
   The resulting jar appears in `subject-programs/jars/`
   or the subject's usual build folder.

### Do the following per project

1. **Create the classpath**: Create a file `wpi-classpath.txt` with the
   project's dependencies, one per line.

   This command tries `mvn`; if that doesn't work, assume that the Ant ships
   extra JARs in a local `jars/` or `lib/` folder.

   ```sh
   if ! mvn -q dependency:build-classpath -Dmdep.outputFile=wpi-classpath.txt; then
     find jars -name '*.jar' > wpi-classpath.txt
     find lib -name '*.jar' >> wpi-classpath.txt
   ```

2. **Run inference**: From the subject directory, execute:

   ```sh
   $CHECKERFRAMEWORK/checker/bin/infer-and-annotate.sh \
     "org.checkerframework.framework.util.PurityChecker" \
     "$RUNTIME_CLASSPATH" \
     $(find src -name "*.java")
   ```

   The script rewrites the sources in place with the inferred annotations.

3. **Rebuild**: Repeat the command from step 2 to produce an annotated JAR.
   Copy it to this folder.

### Worked example (a4j-1.0b)

```sh
cd subject-programs/src/a4j-1.0b
ant createJar                              # build the baseline JAR
export CHECKERFRAMEWORK=...                # reuse the env vars above
export PATH="$CHECKERFRAMEWORK/annotation-file-utilities/bin:$PATH"
export JAVAC_JAR="$CHECKERFRAMEWORK/checker/dist/javac.jar"
RUNTIME_CLASSPATH="../../jars/a4j-1.0b.jar:jars/jox116.jar:jars/log4j-1.2.4.jar"
$CHECKERFRAMEWORK/checker/bin/infer-and-annotate.sh \
  "org.checkerframework.framework.util.PurityChecker" \
  "$RUNTIME_CLASSPATH" \
  $(find src -name "*.java")
ant createJar                              # rebuild with annotations
cp dist/a4j.jar ../../annotated-jars/a4j-1.0b.jar
```
