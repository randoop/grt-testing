# This Python script runs the Randoop-generated tests for hamcrest-core-1.3
# using the EvoSuite test runner.  Normally, running the Randoop-generated tests
# directly results in 0 mutants being reported as covered during mutation
# analysis.  However, executing those same tests through the EvoSuite runner
# correctly reports mutant coverage.  This script resolves the 0 mutant coverage
# issue by running the Randoop tests with the EvoSuite runner.

import os
import re
import argparse

def convert_randoop_to_evosuite_runner(test_dir):
    test_file_pattern = re.compile(r"RegressionTest\d+\.java$")
    fix_method_order_pattern = re.compile(
        r"@FixMethodOrder\s*\(\s*MethodSorters\.NAME_ASCENDING\s*\)"
    )

    new_imports = [
        "import org.evosuite.runtime.EvoRunner;",
        "import org.evosuite.runtime.EvoRunnerParameters;",
        "import org.junit.runner.RunWith;",
    ]

    fix_method_order_replacement = (
        "@RunWith(EvoRunner.class) "
        "@EvoRunnerParameters(mockJVMNonDeterminism = true, "
        "useVFS = true, useVNET = true, resetStaticState = true, "
        "separateClassLoader = true)"
    )

    for root, dirs, files in os.walk(test_dir):
        for file in files:
            if not test_file_pattern.match(file):
                continue

            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            import_end_index = 0
            for i, line in enumerate(lines):
                stripped = line.strip()
                if stripped.startswith("package") or stripped.startswith("import"):
                    import_end_index = i + 1

            existing_imports = set(
                line.strip() for line in lines if line.strip().startswith("import")
            )

            for import_line in reversed(new_imports):
                if import_line not in existing_imports:
                    lines.insert(import_end_index, import_line + "\n")

            for i, line in enumerate(lines):
                if fix_method_order_pattern.search(line):
                    lines[i] = fix_method_order_replacement + "\n"
                    break

            with open(file_path, "w", encoding="utf-8") as f:
                f.writelines(lines)

            print(f"[EvoSuite Runner] Updated: {file_path}")


def convert_evosuite_to_randoop_runner(test_dir):
    evosuite_test_pattern = re.compile(r".*_ESTest\.java$")
    runner_annotation_pattern = re.compile(
        r"@RunWith\(EvoRunner\.class\)\s*@EvoRunnerParameters\([^)]+\)\s*"
    )
    extends_scaffolding_pattern = re.compile(
        r"public class (\w+_ESTest)\s+extends\s+\w+_ESTest_scaffolding\s*{"
    )

    for root, dirs, files in os.walk(test_dir):
        for file in files:
            if not evosuite_test_pattern.match(file):
                continue

            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            new_lines = []
            skip_next_line = False
            for i, line in enumerate(lines):
                if runner_annotation_pattern.match(line.strip()):
                    skip_next_line = True  # This line is an annotation, skip it
                    continue

                if skip_next_line:
                    # This is the class declaration line to replace
                    match = extends_scaffolding_pattern.match(line.strip())
                    if match:
                        class_name = match.group(1)
                        new_lines.append(f"public class {class_name} {{\n")
                        skip_next_line = False
                        continue

                new_lines.append(line)

            with open(file_path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)

            print(f"[Randoop Runner] Updated: {file_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert test runners between Randoop and EvoSuite.")
    parser.add_argument("test_dir", type=str, help="Path to the test directory")
    parser.add_argument(
        "--mode",
        choices=["randoop-to-evosuite", "evosuite-to-randoop"],
        required=True,
        help="Conversion direction",
    )
    args = parser.parse_args()

    if args.mode == "randoop-to-evosuite":
        convert_randoop_to_evosuite_runner(args.test_dir)
    elif args.mode == "evosuite-to-randoop":
        convert_evosuite_to_randoop_runner(args.test_dir)
