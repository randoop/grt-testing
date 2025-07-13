"""Run the Randoop-generated tests for hamcrest-core-1.3 using the EvoSuite test runner.

Normally, running the Randoop-generated tests directly results in 0
mutants being reported as covered during mutation analysis.  However,
executing those same tests through the EvoSuite runner correctly
reports mutant coverage.  This script resolves the 0 mutant coverage
issue by running the Randoop tests with the EvoSuite runner.
"""

import argparse
import os
import re
from pathlib import Path

# Parse arguments
parser = argparse.ArgumentParser(description="Update Java regression test files.")
parser.add_argument(
    "test_dir",
    type=str,
    help="Path to the directory containing RegressionTest Java files",
)
args = parser.parse_args()
test_dir = args.test_dir

# Regex patterns
test_file_pattern = re.compile(r"RegressionTest\d+\.java$")
fix_method_order_pattern = re.compile(r"@FixMethodOrder\s*\(\s*MethodSorters\.NAME_ASCENDING\s*\)")

# The new import lines to add
new_imports = [
    "import org.evosuite.runtime.EvoRunner;",
    "import org.evosuite.runtime.EvoRunnerParameters;",
    "import org.junit.runner.RunWith;",
]

# The new annotations to replace @FixMethodOrder
fix_method_order_replacement = (
    "@RunWith(EvoRunner.class) "
    "@EvoRunnerParameters(mockJVMNonDeterminism = true, "
    "useVFS = true, useVNET = true, resetStaticState = true, "
    "separateClassLoader = true)"
)

# Walk through the directory and process matching files
for root, _dirs, files in os.walk(test_dir):
    for file in files:
        if not test_file_pattern.match(file):
            continue

        file_path = Path(root) / file
        with Path.open(file_path, encoding="utf-8") as f:
            lines = f.readlines()

        # Find end of import statements
        import_end_index = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith(("package", "import")):
                import_end_index = i + 1

        # Collect existing stripped import lines for comparison
        existing_imports = {line.strip() for line in lines if line.strip().startswith("import")}

        # Insert new imports if they are not already there
        for import_line in reversed(new_imports):
            if import_line not in existing_imports:
                lines.insert(import_end_index, import_line + "\n")

        # Replace @FixMethodOrder annotation
        for i, line in enumerate(lines):
            if fix_method_order_pattern.search(line):
                lines[i] = fix_method_order_replacement + "\n"
                break

        # Write changes back to the file
        with Path.open(file_path, "w", encoding="utf-8") as f:
            f.writelines(lines)

        print(f"Updated: {file_path}")
