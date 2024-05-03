import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Optional;

/**
 * This class takes a test suite as input and eliminates the methods in that test suite
 * that fail in isolation.
 */
public class MethodExtractor {

    public static void main(String[] args) throws IOException {
        // Parse the Java source file
        String currFile = args[0];
        String testDirectory = args[1];
        CompilationUnit cu = StaticJavaParser.parse(new File(testDirectory + currFile + ".java"));

        FileWriter passingWriter = new FileWriter(currFile + ".java");
        passingWriter.write("import org.junit.FixMethodOrder;\n");
        passingWriter.write("import org.junit.Test;\n");
        passingWriter.write("import org.junit.runners.MethodSorters;\n\n");
        passingWriter.write("@FixMethodOrder(MethodSorters.NAME_ASCENDING)\n");
        passingWriter.write("public class " + currFile + " { \n\n");
        passingWriter.write("\tpublic static boolean debug = false;\n\n");

        // Iterate through methods and extract
        cu.findAll(MethodDeclaration.class).forEach(method -> {
            String methodSignature = method.getDeclarationAsString(false, false, false);
            Optional<String> optionalMethodBody = method.getBody().map(Object::toString);

            // Write method to a new file
            try {
                writeMethodToTempFile(methodSignature, optionalMethodBody);
                if (compileAndRunTemp(args[2])) {
                    passingWriter.write("\t@Test\n");
                    passingWriter.write("\tpublic " + methodSignature + " throws Throwable");
                    for (String line : optionalMethodBody.orElse("").split("\n")) {
                        passingWriter.write("\t" + line + "\n");
                    }
                    passingWriter.write("\n");
                } else {
                    System.out.println(methodSignature + " failed in isolation. Excluding from test suite.");
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        passingWriter.write("\n}");
        passingWriter.flush();
        passingWriter.close();
    }

    private static void writeMethodToTempFile(String methodSignature, Optional<String> optionalMethodBody) throws IOException {
        String fileName = "Temp.java";
        try (FileWriter writer = new FileWriter(fileName)) {
            String methodBody = optionalMethodBody.orElse("");
            String[] bodyLines = methodBody.split("\n");
            writer.write("import org.junit.FixMethodOrder;\n");
            writer.write("import org.junit.Test;\n");
            writer.write("import org.junit.runners.MethodSorters;\n\n");
            writer.write("@FixMethodOrder(MethodSorters.NAME_ASCENDING)\n");
            writer.write("public class Temp { \n\n");
            writer.write("\tpublic static boolean debug = false;\n\n");
            writer.write("\t@Test\n");
            writer.write("\tpublic " + methodSignature + " throws Throwable\n");
            for (String line : bodyLines) {
                writer.write("\t" + line + "\n");
            }
            writer.write("\n}");
            writer.flush();
            writer.close();
        }
    }

    private static boolean compileAndRunTemp(String jarfiles) throws IOException, InterruptedException {
        Process compileProcess = Runtime.getRuntime().exec("javac -cp " + jarfiles + " Temp.java");
        int compileExitValue = compileProcess.waitFor();
        if (compileExitValue != 0) {
            // If it enters here, this is technically unexpected behavior
            return false;
        }
        Process runProcess = Runtime.getRuntime().exec("java -classpath .:" + jarfiles + " org.junit.runner.JUnitCore Temp");
        int runExitValue = runProcess.waitFor();
        if (runExitValue != 0) {
            // Test fails in isolation, so exclude it
            return false;
        }
        return true;
    }
}
