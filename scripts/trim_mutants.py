#!/usr/bin/env python3
"""
Create an exclude list for redundant mutants from a mutants.log file.

This script reduces the number of mutants by identifying mutants to exclude,
keeping only a limited number per method while preserving diverse mutation operators.
The output is a list of mutant IDs to exclude that can be used with Major's
exclude option.
"""

import argparse
import sys
from collections import defaultdict
from pathlib import Path


def parse_mutant_line(line):
    """Parse a mutant line and extract key information."""
    parts = line.strip().split(":")
    if len(parts) < 7:
        return None

    mutant_id = parts[0]
    operator = parts[1]

    # Find the method identifier (format: CLASS@METHOD or just CLASS)
    # It's the 5th field (index 4)
    method_identifier = parts[4]

    return {
        "id": mutant_id,
        "operator": operator,
        "method": method_identifier,
        "line": line.strip(),
    }


def group_mutants_by_method(mutants_file):
    """Group mutants by their method identifier."""
    method_mutants = defaultdict(list)

    with open(mutants_file, "r") as f:
        for line in f:
            mutant = parse_mutant_line(line)
            if mutant:
                method_mutants[mutant["method"]].append(mutant)

    return method_mutants


def select_diverse_mutants(mutants, max_per_method=3):
    """
    Select a limited number of mutants per method, preferring diversity.

    Strategy:
    1. Group by mutation operator
    2. Select one mutant from each operator type until we hit the limit
    3. If we still have room, add more mutants round-robin style
    """
    if len(mutants) <= max_per_method:
        return mutants

    # Group by operator
    by_operator = defaultdict(list)
    for mutant in mutants:
        by_operator[mutant["operator"]].append(mutant)

    selected = []
    operators = list(by_operator.keys())

    # First pass: select one from each operator type
    for op in operators:
        if len(selected) >= max_per_method:
            break
        selected.append(by_operator[op][0])

    # If we still need more and have fewer operators than max_per_method,
    # add more mutants round-robin
    if len(selected) < max_per_method:
        op_index = 0
        while len(selected) < max_per_method:
            op = operators[op_index % len(operators)]
            # Find the next mutant from this operator that we haven't selected
            for mutant in by_operator[op]:
                if mutant not in selected:
                    selected.append(mutant)
                    break
            op_index += 1
            # Safety check to avoid infinite loop
            if op_index > len(operators) * max_per_method:
                break

    return selected


def trim_mutants(input_file, output_file, max_per_method=3, verbose=False):
    """
    Create an exclude list for mutants to reduce redundancy.

    Args:
        input_file: Path to input mutants.log
        output_file: Path to output exclude_mutants.txt
        max_per_method: Maximum number of mutants to keep per method
        verbose: Print statistics
    """
    # Group mutants by method
    method_mutants = group_mutants_by_method(input_file)

    if verbose:
        total_original = sum(len(mutants) for mutants in method_mutants.values())
        print(f"Original mutants: {total_original}")
        print(f"Methods with mutants: {len(method_mutants)}")
        print(f"Max mutants per method: {max_per_method}")

    # Select mutants to keep
    selected_mutants = []
    all_mutants = []
    for method, mutants in sorted(method_mutants.items()):
        diverse_mutants = select_diverse_mutants(mutants, max_per_method)
        selected_mutants.extend(diverse_mutants)
        all_mutants.extend(mutants)

        if verbose and len(mutants) > max_per_method:
            print(f"  {method}: {len(mutants)} -> {len(diverse_mutants)}")

    # Determine which mutants to exclude (all mutants NOT selected)
    selected_ids = {int(m["id"]) for m in selected_mutants}
    all_ids = {int(m["id"]) for m in all_mutants}
    excluded_ids = sorted(all_ids - selected_ids)

    # Write excluded mutant IDs to file
    with open(output_file, "w") as f:
        for mutant_id in excluded_ids:
            f.write(f"{mutant_id}\n")

    if verbose:
        print(f"\nMutants to keep: {len(selected_mutants)}")
        print(f"Mutants to exclude: {len(excluded_ids)}")
        reduction = (len(excluded_ids) / total_original) * 100
        print(f"Reduction: {reduction:.1f}%")
        print(f"Exclude list written to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Create an exclude list for redundant mutants from a mutants.log file"
    )
    parser.add_argument("input_file", help="Input mutants.log file")
    parser.add_argument(
        "-o",
        "--output",
        help="Output file (default: exclude_mutants.txt in same directory)",
        default=None,
    )
    parser.add_argument(
        "-m",
        "--max-per-method",
        type=int,
        default=3,
        help="Maximum number of mutants to keep per method (default: 3)",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Print detailed statistics")

    args = parser.parse_args()

    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"Error: Input file not found: {args.input_file}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.parent / "exclude_mutants.txt"

    trim_mutants(input_path, output_path, args.max_per_method, args.verbose)


if __name__ == "__main__":
    main()
