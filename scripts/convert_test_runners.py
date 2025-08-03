"""Switches between Randoop and EvoSuite JUnit test runners.

Certain subject programs require specific test runner configurations to ensure correct execution
and accurate mutation analysis results. For instance, some Randoop-generated tests yield no mutant
coverage unless run with EvoSuite's runner, while some EvoSuite-generated tests may fail to load
classes correctly unless executed using a plain JUnit (Randoop-style) runner.

This behavior is most likely related to how the Major mutation analysis tool interacts with
different runners and instrumentation, though the exact cause is uncertain.

This script modifies the annotations and class structure in test files to convert between the
two formats, enabling flexible integration with mutation testing tools across different projects.
"""

import argparse
import os
import re
from pathlib import Path


def main() -> None:
    """Convert test runners between Randoop and EvoSuite.

    Functionality depends on the mode:
    - "randoop-to-evosuite": converts Randoop test runners to EvoSuite format.
    - "evosuite-to-randoop": converts EvoSuite test runners to Randoop format.
    """
    parser = argparse.ArgumentParser(
        description="Convert test runners between Randoop and EvoSuite."
    )
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


def convert_randoop_to_evosuite_runner(test_dir: str) -> None:
    """Convert Randoop-generated test files into a format compatible with the EvoSuite test runner.

    Specifically:
    - Add necessary EvoSuite import statements.
    - Replace the `@FixMethodOrder(MethodSorters.NAME_ASCENDING)` annotation with
      EvoSuite's `@RunWith(EvoRunner.class)` and `@EvoRunnerParameters(...)`.

    This transformation ensures that EvoSuite's runtime environment is properly
    initialized, which is necessary for some mutation testing tools
    to recognize coverage correctly.

    Args:
        test_dir (str): Path to the directory containing test files to convert.
    """
    test_file_pattern = re.compile(r"RegressionTest\d+\.java$")

    fix_method_order_pattern = re.compile(
        r"@FixMethodOrder\s*\(\s*MethodSorters\.NAME_ASCENDING\s*\)"
    )
    fix_method_order_replacement = (
        "@RunWith(EvoRunner.class) "
        "@EvoRunnerParameters(mockJVMNonDeterminism = true, "
        "useVFS = true, useVNET = true, resetStaticState = true, "
        "separateClassLoader = true)"
    )

    new_imports = [
        "import org.evosuite.runtime.EvoRunner;",
        "import org.evosuite.runtime.EvoRunnerParameters;",
        "import org.junit.runner.RunWith;",
    ]

    for root, _dirs, files in os.walk(test_dir):
        for file in files:
            if not test_file_pattern.match(file):
                continue

            file_path = Path(root) / file
            with file_path.open(encoding="utf-8") as f:
                lines = f.readlines()

            import_end_index = 0
            for i, line in enumerate(lines):
                stripped = line.strip()
                if stripped.startswith(("package", "import")):
                    import_end_index = i + 1

            existing_imports = {line.strip() for line in lines if line.strip().startswith("import")}

            for import_line in reversed(new_imports):
                if import_line not in existing_imports:
                    lines.insert(import_end_index, import_line + "\n")

            for i, line in enumerate(lines):
                if fix_method_order_pattern.search(line):
                    lines[i] = fix_method_order_replacement + "\n"
                    break

            with file_path.open("w", encoding="utf-8") as f:
                f.writelines(lines)

            print(f"[EvoSuite Runner] Updated: {file_path}")


def convert_evosuite_to_randoop_runner(test_dir: str) -> None:
    """Convert EvoSuite-generated test files to a plain JUnit format compatible with Randoop tests.

    Specifically:
    - Remove `@RunWith(EvoRunner.class)` and `@EvoRunnerParameters(...)` annotations.
    - Strip off any `extends ..._scaffolding` from the class declaration line,
      reverting it to a standard class declaration.

    This is useful when EvoSuite-generated tests are required to run with a plain JUnit
    (i.e. Randoop) runner, such as in projects like jdom-1.0 that are incompatible with
    EvoSuite instrumentation.

    Args:
        test_dir (str): Path to the directory containing test files to convert.
    """
    evosuite_test_pattern = re.compile(r".*_ESTest\.java$")

    # Swallow lines (no output) from the first regex to the second one.
    runner_annotation_pattern = re.compile(
        r"@RunWith\(EvoRunner\.class\)\s*@EvoRunnerParameters\([^)]+\)\s*"
    )
    extends_scaffolding_pattern = re.compile(
        r"public class (\w+_ESTest)\s+extends\s+\w+_ESTest_scaffolding\s*{"
    )

    for root, _dirs, files in os.walk(test_dir):
        for file in files:
            if not evosuite_test_pattern.match(file):
                continue

            file_path = Path(root) / file
            with file_path.open(encoding="utf-8") as f:
                lines = f.readlines()

            new_lines = []
            skip_next_line = False
            for line in lines:
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

            with file_path.open("w", encoding="utf-8") as f:
                f.writelines(new_lines)

            print(f"[Randoop Runner] Updated: {file_path}")


if __name__ == "__main__":
    main()
