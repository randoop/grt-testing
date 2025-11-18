# Annotated Subject Program JARs

This folder holds the subject JARs after we run Checker Framework whole-program
inference and rewrite the sources with purity annotations. Compared to
`subject-programs/jars/`, the compiled bytecode here is the same, but the
underlying Java files now carry `@Pure`, `@SideEffectFree`, `@Impure`, and
related qualifiers from `org.checkerframework.framework.qual`. No other code or
resources are altered.

## Why the annotations matter

The `GRT_FUZZING` feature in `scripts/mutation-randoop.sh` loads these annotated artifacts and, for each method, determines whether it is pure (no state change) or impure (mutates the receiver, its arguments, or global state). During fuzzing, we prioritize impure calls to mutate an object’s state before exercising additional API entry points. This produces many more distinct runtime states than repeatedly calling pure methods, which in turn helps Randoop uncover deeper behaviors and tricky branch conditions.

## Rebuilding an annotated JAR

1. **Fetch sources** – Run `scripts/get-all-subject-src.sh` to populate
   `subject-programs/src/<subject-program>/`.
2. **Build the plain JAR** – In the subject directory, run the build command
   listed later (also see `subject-programs/README.build`). The result lands in
   `subject-programs/jars/` or the subject’s usual build folder.
3. **Set up inference tooling** – Point your environment at the local Checker
   Framework build:

   ```bash
   export CHECKERFRAMEWORK=/path/to/grt-testing/scripts/build/checker-framework/checker
   export PATH="$CHECKERFRAMEWORK/../annotation-file-utilities/bin:$PATH"
   export JAVAC_JAR="$CHECKERFRAMEWORK/dist/javac.jar"
   ```

4. **Assemble the runtime classpath** – Start with the JAR you just built, then
    append any dependencies:
    - Ant projects usually ship extra JARs in a local `jars/` or `lib/` folder.
    - Maven projects can generate a classpath with
       `mvn -q dependency:build-classpath -Dmdep.outputFile=target/wpi-classpath.txt`.
5. **Run inference** – From the subject directory, execute:

   ```bash
   $CHECKERFRAMEWORK/bin/infer-and-annotate.sh \
     "org.checkerframework.framework.util.PurityChecker" \
     "$RUNTIME_CLASSPATH" \
     $(find src -name "*.java")
   ```

   The script rewrites the sources in-place with the inferred annotations.
6. **Rebuild** – Repeat the command from step 2 to produce an annotated JAR.

### Worked example (a4j-1.0b)

```bash
cd subject-programs/src/a4j-1.0b
ant createJar                              # build the baseline JAR
export CHECKERFRAMEWORK=...                # reuse the env vars above
export PATH="$CHECKERFRAMEWORK/../annotation-file-utilities/bin:$PATH"
export JAVAC_JAR="$CHECKERFRAMEWORK/dist/javac.jar"
RUNTIME_CLASSPATH="../../jars/a4j-1.0b.jar:jars/jox116.jar:jars/log4j-1.2.4.jar"
$CHECKERFRAMEWORK/bin/infer-and-annotate.sh \
  "org.checkerframework.framework.util.PurityChecker" \
  "$RUNTIME_CLASSPATH" \
  $(find src -name "*.java")
ant createJar                              # rebuild with annotations
cp dist/a4j.jar ../../annotated-jars/a4j-1.0b.jar
```
