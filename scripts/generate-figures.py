import pandas as pd
import matplotlib
# Set the Matplotlib backend to 'Agg' for headless environments
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.backends.backend_pdf import PdfPages

# Load the CSV file into a pandas DataFrame
csv_file = 'results/info.csv'
df = pd.read_csv(csv_file)

# Remove the '%' signs and convert the coverage columns to numeric values
df['InstructionCoverage'] = df['InstructionCoverage'].str.rstrip('%').astype(float)
df['BranchCoverage'] = df['BranchCoverage'].str.rstrip('%').astype(float)
df['MutationScore'] = df['MutationScore'].str.rstrip('%').astype(float)

# Function to process data and calculate averages based on RandoopVersion and TimeLimit
def process_data_for_table(df):
    # Group by RandoopVersion and TimeLimit
    grouped = df.groupby(['RandoopVersion', 'TimeLimit']).agg({
        'InstructionCoverage': 'mean',
        'BranchCoverage': 'mean',
        'MutationScore': 'mean'
    }).reset_index()

    return grouped

# Function to generate box and whisker plots
def generate_box_plots(df):
    # Set the plot style
    sns.set(style="whitegrid")

    # Create a figure with subplots for each of the metrics
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    # Instruction Coverage Box Plot
    sns.boxplot(x='TimeLimit', y='InstructionCoverage', hue='RandoopVersion', data=df, ax=axes[0])
    axes[0].set_xlabel('Time Limit (s)')
    axes[0].set_ylabel('Instruction Coverage (%)')
    axes[0].get_legend().set_title('')

    # Branch Coverage Box Plot
    sns.boxplot(x='TimeLimit', y='BranchCoverage', hue='RandoopVersion', data=df, ax=axes[1])
    axes[1].set_xlabel('Time Limit (s)')
    axes[1].set_ylabel('Branch Coverage (%)')
    axes[1].get_legend().set_title('')

    # Mutation Score Box Plot
    sns.boxplot(x='TimeLimit', y='MutationScore', hue='RandoopVersion', data=df, ax=axes[2])
    axes[2].set_xlabel('Time Limit (s)')
    axes[2].set_ylabel('Mutation Score (%)')
    axes[2].get_legend().set_title('')

    return fig

# Function to append the table and plots to a PDF
def save_to_pdf(df):
    # Open a PDF file to append content
    with PdfPages('results/report.pdf') as pdf:

        # Process data for the table
        grouped = process_data_for_table(df)

        # Table Title - Table III
        fig_table = plt.figure(figsize=(8, 6))
        plt.text(0.5, 0.9, 'Table III: Average Coverage and Mutation Scores', ha='center', va='center', fontsize=14, weight='bold')
        plt.axis('off')

        # Print the table inside the PDF
        table_data = []
        for _, row in grouped.iterrows():
            table_data.append([row['TimeLimit'], row['RandoopVersion'], f"{row['InstructionCoverage']:.2f}", 
                               f"{row['BranchCoverage']:.2f}", f"{row['MutationScore']:.2f}"])
        
        table_data.insert(0, ['Time', 'Feature', 'Insn. cov. [%]', 'Branch cov. [%]', 'Mutation score[%]'])
        table = plt.table(cellText=table_data, loc='center', cellLoc='center', colLabels=None, cellColours=None, colWidths=[0.1, 0.2, 0.2, 0.2, 0.2])
        table.auto_set_font_size(False)
        table.set_fontsize(10)
        table.scale(1, 1.5)
        
        # Save the table to the PDF
        pdf.savefig(fig_table)
        plt.close(fig_table)

        # Plot Title - Figure 6
        fig_box_plots = generate_box_plots(df)

        # Figure 6 Title
        plt.suptitle('Figure 6: Box and Whisker Plots of Coverage and Mutation Scores', fontsize=14, weight='bold')

        # Save the plots to the PDF
        pdf.savefig(fig_box_plots)
        plt.close(fig_box_plots)

    print("PDF saved as 'result/report.pdf'")

# Call the function to process the data and save to PDF
save_to_pdf(df)
