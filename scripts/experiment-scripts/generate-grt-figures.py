"""
This script defines utilities to generate plots and tables based on coverage and mutation score.
This script is **not intended to be run directly**.  Instead, use one of these scripts:
    ./mutation-fig6-table3.sh
    ./mutation-fig7.sh
    ./mutation-fig8-9.sh
    ./defects4j-table4.sh

This script supports generation of the following figures:

- Table III: Average metric values per (time budget, tool), aggregated over all subject programs.
- Figure 6: Box-and-whisker plots showing the distribution of metric values across subject programs.
- Figure 7: Branch coverage distribution by GRT component.
- Figures 8-9: Line plots showing the progression of branch coverage over time for each GRT
  component on two hand-picked subject programs.
- Table IV: Number of real bugs detected by GRT, Randoop, and EvoSuite on four Defects4J projects
  under different time budgets (120s, 300s, and 600s). Results are aggregated over 10 runs per fault.

Usage (for reference only):
    python generate-grt-figures.py { fig6-table3 | fig7 | fig8-9 | table4 }
"""

import matplotlib as mpl
import pandas as pd

import argparse
import sys

import matplotlib.figure
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.backends.backend_pdf import PdfPages

mpl.use("Agg")  # For headless environments (without GUI)


def main():
    """Parse arguments, load and process data, and save the selected figure type."""
    parser = argparse.ArgumentParser(description="Generate figures from coverage data.")
    parser.add_argument(
        "figure", choices=["fig6-table3", "fig7", "fig8-9", "table4"], help="Figure to generate"
    )
    args = parser.parse_args()

    raw_df = load_data(f"../results/{args.figure}.csv")

    if args.figure == "table4":
        save_to_pdf(raw_df, args.figure)
    else:
        df = average_over_loops(raw_df)
        save_to_pdf(df, args.figure)


def load_data(csv_file: str) -> pd.DataFrame:
    """
    Load a CSV file containing coverage and mutation score data.

    Args:
        csv_file: Path to the CSV file.

    Returns:
        DataFrame containing the loaded data.
    """
    return pd.read_csv(csv_file)


def average_over_loops(df: pd.DataFrame) -> pd.DataFrame:
    """Average metrics over repeated runs of the same configuration.

    Each (time budget, tool, subject program) configuration is repeated multiple times
    to mitigate randomness. This function computes the average metrics (instruction coverage,
    branch coverage, mutation score) across those repeated runs.

    Args:
        df: Raw data with repeated executions per configuration.

    Returns:
        Data averaged over repeated runs, retaining one row per (tool, timelimit, subject).
    """
    return df.groupby(["Version", "TimeLimit", "FileName"], as_index=False).agg(
        {"InstructionCoverage": "mean", "BranchCoverage": "mean", "MutationScore": "mean"}
    )


def generate_table_3(df: pd.DataFrame) -> mpl.figure.Figure:
    """Generate data for Table III: Average coverage and mutation scores per (tool, timelimit) pair.

    This function performs a second level of aggregation, averaging the previously averaged
    metrics (per tool-time-subject) across all subject programs. The resulting table has
    a single row for each (time limit, tool) configuration.

    Args:
        df: Data averaged over repeated runs (output of `average_over_loops`).

    Returns:
        The composite figure representing Table III.
    """

    grouped = (
        df.groupby(["Version", "TimeLimit"])
        .agg(
            {
                "InstructionCoverage": "mean",
                "BranchCoverage": "mean",
                "MutationScore": "mean",
            }
        )
        .reset_index()
    )

    fig = plt.figure(figsize=(10, 6))
    plt.axis("off")
    plt.axis("off")

    table_data = [["Time", "Feature", "Insn. cov. [%]", "Branch cov. [%]", "Mutation score [%]"]]
    for _, row in grouped.iterrows():
        table_data.append(
            [
                row["TimeLimit"],
                row["Version"],
                f"{row['InstructionCoverage']:.2f}",
                f"{row['BranchCoverage']:.2f}",
                f"{row['MutationScore']:.2f}",
            ]
        )
    table = plt.table(cellText=table_data, loc="center", cellLoc="center")
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 1.5)

    fig.suptitle("Table III: Average Coverage and Mutation Scores", fontsize=16, weight="bold")

    return fig


def generate_fig_6(df: pd.DataFrame) -> mpl.figure.Figure:
    """Generate Figure 6: Box-and-whisker plots for coverage and mutation metrics.

    This visualization shows the distribution of metrics across individual subject programs
    for each (time limit, tool) configuration. It illustrates variability and does not average
    across subject programs.

    Args:
        df: Data averaged over repeated runs (output of `average_over_loops`).

    Returns:
        The composite figure containing three subplots.
    """
    sns.set_theme(style="whitegrid")
    fig, axes = plt.subplots(1, 3, figsize=(18, 6), sharey=False)

    sns.boxplot(
        x="TimeLimit",
        y="InstructionCoverage",
        hue="Version",
        data=df,
        ax=axes[0],
    )
    axes[0].set_xlabel("Time Limit (s)")
    axes[0].set_ylabel("Instruction Coverage (%)")

    sns.boxplot(x="TimeLimit", y="BranchCoverage", hue="Version", data=df, ax=axes[1])
    axes[1].set_xlabel("Time Limit (s)")
    axes[1].set_ylabel("Branch Coverage (%)")

    sns.boxplot(x="TimeLimit", y="MutationScore", hue="Version", data=df, ax=axes[2])
    axes[2].set_xlabel("Time Limit (s)")
    axes[2].set_ylabel("Mutation Score (%)")

    for ax in axes:
        ax.get_legend().remove()

    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(
        handles,
        labels,
        loc="upper center",
        ncol=len(labels),
        fontsize=10,
        title="GRT Component",
        bbox_to_anchor=(0.5, 1.05),
    )

    fig.suptitle(
        "Figure 6: Coverage and Mutation Scores of "
        "Randoop, GRT, and EvoSuite (2s-60s Time Budgets)",
        fontsize=16,
        weight="bold",
        y=1.12,
    )

    fig.tight_layout(rect=(0, 0, 1, 0.95))

    return fig


def generate_fig_7(df: pd.DataFrame) -> mpl.figure.Figure:
    """Generate Figure 7: Box plot of branch coverage by Randoop version.

    This plot visualizes the distribution of branch coverage across subject programs
    for each GRT component, showing how the tool's performance varies.

    Args:
        df: Data averaged over repeated runs (output of `average_over_loops`).

    Returns:
        Box plot figure.
    """
    sns.set_theme(style="whitegrid")
    fig, ax = plt.subplots(figsize=(8, 6))
    sns.boxplot(x="Version", y="BranchCoverage", data=df, ax=ax)
    ax.set_xlabel("GRT Component")
    ax.set_ylabel("Branch Coverage (%)")
    fig.suptitle("Figure 7: Branch Coverage by GRT Component", fontsize=16, weight="bold")
    return fig


def generate_fig_8_9(df: pd.DataFrame) -> list[mpl.figure.Figure]:
    """Generate Figures 8-9: Line plots showing branch coverage over time per subject.

    This figure plots branch coverage for each subject program across time limits,
    comparing performance of different GRT components.

    Args:
        df: Data averaged over repeated runs (output of `average_over_loops`).

    Returns:
        One figure per subject.
    """
    sns.set_theme(style="whitegrid")
    grouped = (
        df.groupby(["FileName", "TimeLimit", "Version"])["BranchCoverage"].mean().reset_index()
    )
    figures = []
    for subject in grouped["FileName"].unique():
        fig, ax = plt.subplots(figsize=(10, 6))
        subject_data = grouped[grouped["FileName"] == subject]
        for version in subject_data["Version"].unique():
            version_data = subject_data[subject_data["Version"] == version]
            ax.plot(
                version_data["TimeLimit"],
                version_data["BranchCoverage"],
                label=version,
                marker="o",
            )

        fig.suptitle(
            f"Figure 8-9: Branch Coverage over Time — {subject}",
            fontsize=16,
            weight="bold",
        )
        ax.set_xlabel("Time Limit (s)")
        ax.set_ylabel("Branch Coverage (%)")
        ax.legend(title="GRT Component")
        figures.append(fig)

    return figures


def generate_table_4(df: pd.DataFrame) -> mpl.figure.Figure:
    """
    Generate Table IV: Number of real faults detected by each tool (GRT, Randoop, EvoSuite)
    on different subject programs under different time budgets.

    Args:
        df: Raw data loaded from the CSV for table4.

    Returns:
        Matplotlib Figure object containing the table.
    """
    df.columns = [col.strip() for col in df.columns]
    df["TestClassification"] = df["TestClassification"].str.strip().str.lower()

    # Mark each bug (Version) as detected if ANY test case for it fails.
    df["Detected"] = df["TestClassification"] == "fail"
    bug_detection = (
        df.groupby(["ProjectId", "Version", "TimeLimit", "TestSuiteSource"])["Detected"]
        .any()
        .reset_index()
    )

    # Count how many bugs were detected per (ProjectId, TimeLimit, TestSuiteSource).
    summary = (
        bug_detection.groupby(["ProjectId", "TimeLimit", "TestSuiteSource"])["Detected"]
        .sum()
        .reset_index()
        .rename(columns={"Detected": "FaultsDetected"})
    )

    # Pivot for better tabular display.
    table_data = summary.pivot_table(
        index=["ProjectId", "TimeLimit"],
        columns="TestSuiteSource",
        values="FaultsDetected",
        fill_value=0,
    ).reset_index()

    # Create figure and table.
    fig = plt.figure(figsize=(10, 6))
    plt.axis("off")

    # Table headers.
    headers = ["Project", "Time"] + list(table_data.columns[2:])
    cell_data = [headers] + table_data.values.tolist()

    table = plt.table(cellText=cell_data, loc="center", cellLoc="center")
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 1.5)

    fig.suptitle(
        "Table IV: Real Faults Detected by Tool and Time Budget", fontsize=16, weight="bold"
    )
    return fig


def save_to_pdf(df: pd.DataFrame, fig_type: str):
    """
    Save a figure/table of the given type to a PDF file.

    Args:
        df: Data averaged over repeated runs (output of `average_over_loops`).
        fig_type: One of: 'fig6-table3', 'fig7', 'fig8-9'.
    """
    pdf_filename = f"../results/{fig_type}.pdf"

    with PdfPages(pdf_filename) as pdf:
        if fig_type == "fig6-table3":
            table_3 = generate_table_3(df)
            pdf.savefig(table_3)
            plt.close(table_3)

            fig_6 = generate_fig_6(df)
            pdf.savefig(fig_6)
            plt.close(fig_6)

        elif fig_type == "fig7":
            fig_7 = generate_fig_7(df)
            pdf.savefig(fig_7)
            plt.close(fig_7)

        elif fig_type == "fig8-9":
            figs = generate_fig_8_9(df)
            for fig in figs:
                pdf.savefig(fig)
                plt.close(fig)

        elif fig_type == "table4":
            fig = generate_table_4(df)
            pdf.savefig(fig)
            plt.close(fig)

        else:
            print("Unknown figure type. Use one of: fig6-table3, fig7, fig8-9.")
            sys.exit(1)

    print(f"PDF saved as '{pdf_filename}'")


if __name__ == "__main__":
    main()
