import os
import re
import argparse

# Define the pattern to search for
runner_pattern = r'@RunWith\(EvoRunner\.class\)\s+@EvoRunnerParameters\((.*?)\)'

# Define the pattern for separateClassLoader flag
separate_class_loader_pattern = r'\s*separateClassLoader\s*=\s*(true|false)\s*'

# Custom function to convert string 'true'/'false' to boolean
def str_to_bool(value):
    if value.lower() in ['true', '1', 't', 'y', 'yes']:
        return True
    elif value.lower() in ['false', '0', 'f', 'n', 'no']:
        return False
    else:
        raise argparse.ArgumentTypeError(f"Boolean value expected, but got '{value}'")

def process_file(file_path, separate_class_loader):
    try:
        with open(file_path, 'r') as file:
            lines = file.readlines()

        modified = False
        updated_lines = []

        for line in lines:
            match = re.search(r'@RunWith\(EvoRunner\.class\)\s+@EvoRunnerParameters\((.*?)\)', line)
            if match:
                params = match.group(1)
                # Check if the separateClassLoader flag is present
                separate_match = re.search(r'separateClassLoader\s*=\s*(true|false)', params)

                if separate_match:
                    # If it is true or false, modify it based on the separateClassLoader argument
                    current_value = separate_match.group(1)
                    if current_value != str(separate_class_loader).lower():
                        params = re.sub(r'separateClassLoader\s*=\s*(true|false)', f'separateClassLoader = {str(separate_class_loader).lower()}', params)
                        modified = True
                else:
                    # Add separateClassLoader flag with the desired value if it doesn't exist
                    params += f', separateClassLoader = {str(separate_class_loader).lower()}'
                    modified = True

                # Reconstruct the line with the updated parameters
                updated_line = f'@RunWith(EvoRunner.class) @EvoRunnerParameters({params})\n'
                updated_lines.append(updated_line)
            else:
                updated_lines.append(line)

        if modified:
            with open(file_path, 'w') as file:
                file.writelines(updated_lines)
            print(f"Updated: {file_path}")
        else:
            print(f"No change needed: {file_path}")

    except Exception as e:
        print(f"Error processing file {file_path}: {e}")

def process_directory(directory, separate_class_loader):
    # Walk through all files in the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('Test.java'):  # Only process files that end with Test.java
                file_path = os.path.join(root, file)
                process_file(file_path, separate_class_loader)

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Modify Java files with EvoRunner parameters.')
    parser.add_argument('-d', '--directory', type=str, required=True, help='Directory to search for Java files')
    parser.add_argument('-s', '--separateClassLoader', type=str_to_bool, default=True, help='Set separateClassLoader to True or False')

    args = parser.parse_args()

    # Call the function to process files with the arguments
    process_directory(args.directory, args.separateClassLoader)

if __name__ == '__main__':
    main()
