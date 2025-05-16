import pandas as pd
import matplotlib
matplotlib.use('Agg') # For headless environments
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.backends.backend_pdf import PdfPages
import argparse
import sys

# Load and clean the CSV data
def load_and_clean_data(csv_file='results/info.csv'):
    df = pd.read_csv(csv_file)
    df['InstructionCoverage'] = df['InstructionCoverage'].str.rstrip('%').astype(float)
    df['BranchCoverage'] = df['BranchCoverage'].str.rstrip('%').astype(float)
    df['MutationScore'] = df['MutationScore'].str.rstrip('%').astype(float)
    return df

def average_over_loops(df):
    # Averages the metrics for each unique configuration:
    # (time budget, tool, and subject program).
    # As described in the paper, each configuration is executed NUM_LOOP times.
    # This step computes the average metric values across those repeated runs.
    df_avg = df.groupby(['RandoopVersion', 'TimeLimit', 'FileName'], as_index=False).agg({
        'InstructionCoverage': 'mean',
        'BranchCoverage': 'mean',
        'MutationScore': 'mean'
    })
    return df_avg

# Table III and Figure 6
def generate_table_3(df):
    grouped = df.groupby(['RandoopVersion', 'TimeLimit']).agg({
        'InstructionCoverage': 'mean',
        'BranchCoverage': 'mean',
        'MutationScore': 'mean'
    }).reset_index()
    return grouped

def generate_fig_6(df):
    sns.set(style="whitegrid")
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    sns.boxplot(x='TimeLimit', y='InstructionCoverage', hue='RandoopVersion', data=df, ax=axes[0])
    axes[0].set_xlabel('Time Limit (s)')
    axes[0].set_ylabel('Instruction Coverage (%)')
    axes[0].get_legend().set_title('')

    sns.boxplot(x='TimeLimit', y='BranchCoverage', hue='RandoopVersion', data=df, ax=axes[1])
    axes[1].set_xlabel('Time Limit (s)')
    axes[1].set_ylabel('Branch Coverage (%)')
    axes[1].get_legend().set_title('')

    sns.boxplot(x='TimeLimit', y='MutationScore', hue='RandoopVersion', data=df, ax=axes[2])
    axes[2].set_xlabel('Time Limit (s)')
    axes[2].set_ylabel('Mutation Score (%)')
    axes[2].get_legend().set_title('')

    return fig

def generate_fig_7(df):
    sns.set(style="whitegrid")
    fig, ax = plt.subplots(figsize=(8, 6))
    sns.boxplot(x='RandoopVersion', y='BranchCoverage', data=df, ax=ax)
    ax.set_xlabel('Randoop Version')
    ax.set_ylabel('Branch Coverage (%)')
    ax.set_title('Figure 7: Branch Coverage by Randoop Version', fontsize=14, weight='bold')
    return fig

def generate_fig_8_9(df):
    sns.set(style="whitegrid")
    # Group and average branch coverage per subject, time, version
    grouped = df.groupby(['FileName', 'TimeLimit', 'RandoopVersion'])['BranchCoverage'].mean().reset_index()
    figures = []
    for subject in grouped['FileName'].unique():
        fig, ax = plt.subplots(figsize=(10, 6))
        subject_data = grouped[grouped['FileName'] == subject]

        for version in subject_data['RandoopVersion'].unique():
            version_data = subject_data[subject_data['RandoopVersion'] == version]
            ax.plot(version_data['TimeLimit'], version_data['BranchCoverage'], label=version, marker='o')

        ax.set_title(f'Figure 8-9: Branch Coverage over Time — {subject}', fontsize=14, weight='bold')
        ax.set_xlabel('Time Limit (s)')
        ax.set_ylabel('Branch Coverage (%)')
        ax.legend(title='Randoop Version')
        figures.append(fig)

    return figures

def save_to_pdf(df, fig_type):
    with PdfPages('results/report.pdf') as pdf:
        if fig_type == 'fig6-table3':
            grouped = generate_table_3(df)
            fig_table = plt.figure(figsize=(8, 6))
            plt.text(0.5, 0.9, 'Table III: Average Coverage and Mutation Scores', ha='center', va='center', fontsize=14, weight='bold')
            plt.axis('off')
            table_data = []
            for _, row in grouped.iterrows():
                table_data.append([row['TimeLimit'], row['RandoopVersion'], f"{row['InstructionCoverage']:.2f}",
                                f"{row['BranchCoverage']:.2f}", f"{row['MutationScore']:.2f}"])
            table_data.insert(0, ['Time', 'Feature', 'Insn. cov. [%]', 'Branch cov. [%]', 'Mutation score[%]'])
            table = plt.table(cellText=table_data, loc='center', cellLoc='center')
            table.auto_set_font_size(False)
            table.set_fontsize(10)
            table.scale(1, 1.5)
            pdf.savefig(fig_table)
            plt.close(fig_table)

            fig = generate_fig_6(df)
            plt.suptitle('Figure 6: Box and Whisker Plots of Coverage and Mutation Scores', fontsize=14, weight='bold')
            pdf.savefig(fig)
            plt.close(fig)

        elif fig_type == 'fig7':
            fig = generate_fig_7(df)
            pdf.savefig(fig)
            plt.close(fig)

        elif fig_type == 'fig8-9':
            figs = generate_fig_8_9(df)
            for fig in figs:
                pdf.savefig(fig)
                plt.close(fig)

        else:
            print("Unknown figure type. Use one of: fig6-table3, fig7, fig8-9.")
            sys.exit(1)

    print("PDF saved as 'results/report.pdf'")

def main():
    parser = argparse.ArgumentParser(description='Generate figures from coverage data.')
    parser.add_argument('figure', choices=['fig6-table3', 'fig7', 'fig8-9'], help='Figure to generate')
    args = parser.parse_args()

    df = load_and_clean_data()
    df_avg = average_over_loops(df)
    save_to_pdf(df_avg, args.figure)

if __name__ == "__main__":
    main()